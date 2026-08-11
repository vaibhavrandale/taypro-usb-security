#Requires -RunAsAdministrator

$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

$InstallPath = "C:\ProgramData\Taypro\USBSecurity"
$StateFile = Join-Path $InstallPath "usb-storage-state.json"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TAYPRO USB STORAGE RESTORER"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""


if (-not (Test-Path $RegistryPath)) {

    Write-Host "ERROR: USBSTOR registry path not found." `
        -ForegroundColor Red

    exit 1
}


try {

    # ------------------------------------------
    # Read saved state
    # ------------------------------------------

    if (-not (Test-Path $StateFile)) {

        Write-Host ""
        Write-Host "WARNING: Original USBSTOR state not found." `
            -ForegroundColor Yellow

        Write-Host "USBSTOR configuration was NOT changed."

        exit 0
    }


    $State = Get-Content `
        -Path $StateFile `
        -Raw `
        -ErrorAction Stop |
        ConvertFrom-Json


    $OriginalValue = [int]$State.OriginalStartValue


    # ------------------------------------------
    # Restore original value
    # ------------------------------------------

    Set-ItemProperty `
        -Path $RegistryPath `
        -Name "Start" `
        -Type DWord `
        -Value $OriginalValue `
        -ErrorAction Stop


    # ------------------------------------------
    # Verify
    # ------------------------------------------

    $CurrentValue = (
        Get-ItemProperty `
            -Path $RegistryPath `
            -Name "Start" `
            -ErrorAction Stop
    ).Start


    if ($CurrentValue -ne $OriginalValue) {

        throw "USBSTOR value could not be restored."
    }


    Write-Host ""
    Write-Host "USB STORAGE CONFIGURATION RESTORED." `
        -ForegroundColor Green

    Write-Host "USBSTOR Start = $CurrentValue" `
        -ForegroundColor Green

    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "ERROR: Failed to restore USB storage." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}
