Function Log
{
	<#
	.SYNOPSIS
	Outputs string to console and to a file

	.PARAMETER logFile
	File to log to
	
	.PARAMETER message
	String to log

	#>
	
	Param(
		[Parameter(Mandatory=$true)] [string]$logFile,
		[Parameter(Mandatory=$true)] [string]$message
	)
	
	$logFilePath = "c:\cfn\logs\$logFile"
	
	If(! (Test-Path -Path "$logFilePath") )
	{
		New-Item "$logFilePath" -Type file -Force
	}
	
	Write-Host $message
	Write-Host ""
	Add-Content "$logFilePath" $message
}

Function Test-Online
{
	<#
	.SYNOPSIS
	Tests RPC connection to a server

	.PARAMETER computerName
	Name of computer to test
	
	.PARAMETER credential
	Credential used to test connection to remote computer

	#>
	
	Param(
		[Parameter(Mandatory=$true)]  [string]$computerName,
		[Parameter(Mandatory=$false)] [string]$credential
	)
	
	# Number of attempts made to test if computer is online
	$attempts = 10
	# Number out of attempts made that, if true, will result in a success
	$threshold = 10
	# Number of seconds to wait between attempts
	$timeout = 1
	# Number of successful attempts
	$successes = 0
	
	# Clear DNS cache
	ipconfig /flushdns
	
	For($i = 0; $i -lt $attempts; $i++){
		If($credential) {
			If (Get-WmiObject Win32_ComputerSystem -ComputerName $computerName -Credential $credential -ErrorAction SilentlyContinue) {
				$successes += 1
			}
		}
		Else {
			If (Get-WmiObject Win32_ComputerSystem -ComputerName $computerName -ErrorAction SilentlyContinue) {
				$successes += 1
			}
		}
		Start-Sleep -s $timeout
	}
	
	If($successes -ge $threshold) {
		Return $True
	}
	Else {
		Return $False
	}
	
}