Set-Location -Path ($MyInvocation.MyCommand.Path -replace '\\[^\\]+$')
Import-Module .\WingetInstaller.psm1
Install-Winget -Save H:\Software\Winget
