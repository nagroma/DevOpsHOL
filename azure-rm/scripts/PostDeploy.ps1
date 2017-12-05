Param(
    [string]$ChocoPackages,
    [string]$VmAdminUserName,
    [Security.SecureString]$VmAdminPassword
)

cls

New-Item "c:\choco" -type Directory -force | Out-Null
$LogFile = "c:\choco\PostDeploy.log"
$ChocoPackages | Out-File $LogFile -Append
$VmAdminUserName | Out-File $LogFile -Append
$VmAdminPassword | Out-File $LogFile -Append

$secPassword = ConvertTo-SecureString $VmAdminPassword -AsPlainText -Force		
$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($VmAdminUserName)", $secPassword)

# Ensure that current process can run scripts. 
"Enabling remoting" | Out-File $LogFile -Append
Enable-PSRemoting -Force -SkipNetworkProfileCheck

"Changing ExecutionPolicy" | Out-File $LogFile -Append
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#"Install each Chocolatey Package"
if (-not [String]::IsNullOrWhiteSpace($ChocoPackages)){
    $ChocoPackages.Split(";") | ForEach {
        $command = "cinst " + $_ + " -y -force"
        $command | Out-File $LogFile -Append
        $sb = [scriptblock]::Create("$command")

        # Use the current user profile
        Invoke-Command -ScriptBlock $sb -ArgumentList $ChocoPackages -ComputerName $env:COMPUTERNAME -Credential $credential | Out-Null
    }
}

"Configuring Extras" | Out-File $LogFile -Append
Invoke-Command -ScriptBlock {
    # Show file extensions (have to restart Explorer for this to take effect if run maually - Stop-Process -processName: Explorer -force)
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -Value "0"

    Set-TimeZone -Name "Eastern Standard Time"

    Enable-WindowsOptionalFeature –online –featurename IIS-WebServerRole

} -ComputerName $env:COMPUTERNAME -Credential $credential | Out-File $LogFile -Append

Disable-PSRemoting -Force
