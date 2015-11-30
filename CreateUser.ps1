<#
.SYNOPSIS
Create user in Active Directory
Create mailbox for the user

#>

Import-Module ActiveDirectory
Import-Module helpers.psm1
$logFile="logs\CreateUser.log"

$timeout=30

$DomainControllerFQDN = ""

foreach($User in $Users) {

	# Attributes
	$Username = $User.Username
	$DisplayName = $User.DisplayName
	$UserPrincipalName = $User.UserPrincipalName
	$GivenName = $User.GivenName
	$Surname = $User.Surname
	$Description = $User.Description
	$Title = $User.Title
	$PrimarySMTPAddress = $User.PrimarySMTPAddress
	$Department = $User.Department
	$Path = $User.Path
	$Password = $User.Password
	$SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
	$ChangePasswordAtLogon = $True
	$PasswordNeverExpires = $False

	$userNotCreated=$True
	While($userNotCreated) {
		If (Test-Online -computerName $DomainControllerFQDN) {
			# Find a user, if it exists
			$ExistingUser = Get-ADUser -LDAPFilter "(sAMAccountName=$Username)"
			
			# If the user does not exist, create it
			If ($ExistingUser -eq $Null) 
			{	
				Log -logFile $logFile -message "$Username does not exist. Creating..."

				New-ADUser -Name $DisplayName -UserPrincipalName $UserPrincipalName -SamAccountName $Username -GivenName $GivenName -DisplayName `
				$DisplayName -SurName $Surname -Description $Description —Title $Title -Department $Department -Path $Path -AccountPassword $SecurePassword `
				-Enabled $True -PasswordNeverExpires $PasswordNeverExpires -ChangePasswordAtLogon $ChangePasswordAtLogon

				Log -logFile $logFile -message “Creating mailbox for $Username..”
				Enable-Mailbox -Identity $UserPrincipalName

				Log -logFile $logFile -message “Setting SMTP addresses..”
				Set-Mailbox -Identity $UserPrincipalName -EmailAddresses @{Remove=“SMTP:$UserPrincipalName”,Add=“smtp:$UserPrincipalName”,Add=“SMTP=$PrimarySMTPAddress”}

				Log -logFile $logFile -message “Connecting to Office 365..”
				$UserCredential = Get-Credential -Message “Enter in Office 365 credentials”
				$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
				Import-PSSession $Session

				Log -logFile $logFile -message “Migrating mailbox to Office 365..”
				$RemoteCredential = Get-Credential -Message “Enter in on-premise Exchange credentials”
				New-MoveRequest -Identity $UserPrincipalName -Remote -RemoteHostName webmail.landair.com -TargetDeliveryDomain “LandairTransportInc.mail.onmicrosoft.com” -RemoteCredential $RemoteCredential
				
			}
			# Else, the user already exists, so update any relevant information
			Else
			{
				Log -logFile $logFile -message "$Username already exists."
				$UserToUpdate = Get-ADUser -Identity $Username
				$ExistingUserDescription = $UserToUpdate.$Description
				
				# If description is not provided or has changed
				If ($Description -eq $Null -Or
					$ExistingUserDescription -ne $Description)
				{
					Log -logFile $logFile -message "Changing description for $Username..."
					$UserToUpdate.Description = $Description
					Set-ADUser -Instance $UserToUpdate
					If($Administrator -eq "TRUE")
					{ Add-ADGroupMember -Identity "Domain Admins" -Member $Username }
				}
				# Else, skip it
				Else
				{
					Log -logFile $logFile -message "Description has not changed for $Username."
				}
			}
			# Add a blank line to separate users
			Log -logFile $logFile -message " "
			$userNotCreated=$False
		}
		Else
		{
			# In case the domain controller is not ready, give it some time
			Log -logFile $logFile -message "Waiting $timeout seconds for the domain controller to come online to add $DisplayName..."
			Start-Sleep -s $timeout
		}
	}
}