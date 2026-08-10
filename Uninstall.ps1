#Requires -RunAsAdministrator

$TaskName = "Taypro USB Security Monitor"
$InstallPath = "C:\ProgramData\Taypro\USBSecurity"

Write-Host "Stopping Taypro USB Security..."

Stop-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

Unregister-ScheduledTask `
    -TaskName $TaskName `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

Write-Host "Scheduled task removed."

if (Test-Path $InstallPath) {

    Remove-Item `
        $InstallPath `
        -Recurse `
        -Force
}

Write-Host ""
Write-Host "Taypro USB Security removed." -ForegroundColor Green