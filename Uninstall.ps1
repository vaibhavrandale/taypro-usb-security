# #Requires -RunAsAdministrator

# $TaskName = "Taypro USB Security Monitor"
# $InstallPath = "C:\ProgramData\Taypro\USBSecurity"

# Write-Host "Stopping Taypro USB Security..."

# Stop-ScheduledTask `
#     -TaskName $TaskName `
#     -ErrorAction SilentlyContinue

# Unregister-ScheduledTask `
#     -TaskName $TaskName `
#     -Confirm:$false `
#     -ErrorAction SilentlyContinue

# Write-Host "Scheduled task removed."

# if (Test-Path $InstallPath) {

#     Remove-Item `
#         $InstallPath `
#         -Recurse `
#         -Force
# }

# Write-Host ""
# Write-Host "Taypro USB Security removed." -ForegroundColor Green


#Requires -RunAsAdministrator

# ==========================================
# TAYPRO USB SECURITY UNINSTALLER
# ==========================================

$ErrorActionPreference = "Stop"

$TaskName = "Taypro USB Security Monitor"
$InstallPath = "C:\ProgramData\Taypro\USBSecurity"
$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host " TAYPRO USB SECURITY UNINSTALLER" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""

# ==========================================
# CHECK ADMIN
# ==========================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object Security.Principal.WindowsPrincipal(
    $CurrentIdentity
)

if (-not $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {

    Write-Host "ERROR: Please run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

# ==========================================
# STOP SCHEDULED TASK
# ==========================================

Write-Host "Stopping Taypro USB Security..."

$Task = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

if ($Task) {

    Stop-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2

    Write-Host "USB Security monitor stopped." -ForegroundColor Green
}
else {

    Write-Host "Scheduled task not found." -ForegroundColor Yellow
}

# ==========================================
# REMOVE SCHEDULED TASK
# ==========================================

Write-Host "Removing scheduled task..."

Unregister-ScheduledTask `
    -TaskName $TaskName `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

Write-Host "Scheduled task removed." -ForegroundColor Green

# ==========================================
# RESTORE USB STORAGE
# ==========================================

Write-Host ""
Write-Host "Restoring USB storage access..."

try {

    if (-not (Test-Path $RegistryPath)) {

        Write-Host "USBSTOR registry key not found." -ForegroundColor Yellow

    }
    else {

        # 3 = USB storage enabled
        Set-ItemProperty `
            -Path $RegistryPath `
            -Name "Start" `
            -Type DWord `
            -Value 3

        $USBSTORStart = (
            Get-ItemProperty `
                -Path $RegistryPath `
                -Name "Start"
        ).Start

        if ($USBSTORStart -eq 3) {

            Write-Host "USB storage restored successfully. Start = 3" `
                -ForegroundColor Green

        }
        else {

            Write-Host "ERROR: USBSTOR Start is $USBSTORStart" `
                -ForegroundColor Red

        }
    }
}
catch {

    Write-Host "ERROR restoring USB storage: $($_.Exception.Message)" `
        -ForegroundColor Red

}

# ==========================================
# REMOVE INSTALLATION DIRECTORY
# ==========================================

Write-Host ""
Write-Host "Removing installation files..."

if (Test-Path $InstallPath) {

    Remove-Item `
        $InstallPath `
        -Recurse `
        -Force

    Write-Host "Installation directory removed." `
        -ForegroundColor Green
}
else {

    Write-Host "Installation directory not found." `
        -ForegroundColor Yellow
}

# ==========================================
# VERIFY USB STORAGE
# ==========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " VERIFYING USB STORAGE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

try {

    $FinalUSBSTORStart = (
        Get-ItemProperty `
            -Path $RegistryPath `
            -Name "Start"
    ).Start

    Write-Host ""
    Write-Host "USBSTOR Start value: $FinalUSBSTORStart"

    if ($FinalUSBSTORStart -eq 3) {

        Write-Host ""
        Write-Host "USB STORAGE IS ENABLED." `
            -ForegroundColor Green

    }
    else {

        Write-Host ""
        Write-Host "WARNING: USB storage is still blocked." `
            -ForegroundColor Red

    }

}
catch {

    Write-Host "Unable to verify USBSTOR registry value." `
        -ForegroundColor Red
}

# ==========================================
# COMPLETE
# ==========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " TAYPRO USB SECURITY REMOVED" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Scheduled Task : Removed"
Write-Host "Install Path   : Removed"
Write-Host "USBSTOR Start  : $FinalUSBSTORStart"
Write-Host ""

if ($FinalUSBSTORStart -eq 3) {
    Write-Host "USB storage access has been restored." `
        -ForegroundColor Green
}
else {
    Write-Host "USB storage access may still be blocked." `
        -ForegroundColor Red
}

Write-Host ""
Write-Host "A restart may be required for Windows to fully apply the USB storage change." `
    -ForegroundColor Yellow
Write-Host ""
