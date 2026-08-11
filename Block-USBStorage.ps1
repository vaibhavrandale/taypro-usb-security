# #Requires -RunAsAdministrator

# $RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

# $InstallPath = "C:\ProgramData\Taypro\USBSecurity"
# $StateFile = Join-Path $InstallPath "usb-storage-state.json"

# Write-Host ""
# Write-Host "==========================================" -ForegroundColor Yellow
# Write-Host " TAYPRO USB STORAGE BLOCKER"
# Write-Host "==========================================" -ForegroundColor Yellow
# Write-Host ""

# # ------------------------------------------
# # Create installation directory
# # ------------------------------------------

# if (-not (Test-Path $InstallPath)) {

#     New-Item `
#         -ItemType Directory `
#         -Path $InstallPath `
#         -Force | Out-Null
# }


# # ------------------------------------------
# # Check registry path
# # ------------------------------------------

# if (-not (Test-Path $RegistryPath)) {

#     Write-Host "ERROR: USBSTOR registry path not found." `
#         -ForegroundColor Red

#     exit 1
# }


# try {

#     # ------------------------------------------
#     # Read current value
#     # ------------------------------------------

#     $CurrentValue = (
#         Get-ItemProperty `
#             -Path $RegistryPath `
#             -Name "Start" `
#             -ErrorAction Stop
#     ).Start

#     Write-Host "Current USBSTOR Start value: $CurrentValue"


#     # ------------------------------------------
#     # Save original value
#     # ------------------------------------------

#     if (-not (Test-Path $StateFile)) {

#         $State = [PSCustomObject]@{
#             OriginalStartValue = [int]$CurrentValue
#             ChangedByTaypro     = $true
#             ChangedAt           = (Get-Date).ToString(
#                 "yyyy-MM-dd HH:mm:ss"
#             )
#         }

#         $State |
#             ConvertTo-Json |
#             Set-Content `
#                 -Path $StateFile `
#                 -Encoding UTF8 `
#                 -Force

#         Write-Host "Original USBSTOR state saved."
#     }
#     else {

#         Write-Host "Original USBSTOR state already saved."
#     }


#     # ------------------------------------------
#     # Disable USB storage
#     # ------------------------------------------

#     Set-ItemProperty `
#         -Path $RegistryPath `
#         -Name "Start" `
#         -Type DWord `
#         -Value 4 `
#         -ErrorAction Stop


#     # ------------------------------------------
#     # Verify
#     # ------------------------------------------

#     $NewValue = (
#         Get-ItemProperty `
#             -Path $RegistryPath `
#             -Name "Start" `
#             -ErrorAction Stop
#     ).Start


#     if ($NewValue -ne 4) {

#         throw "USBSTOR Start value was not changed to 4."
#     }


#     Write-Host ""
#     Write-Host "USB STORAGE BLOCKED SUCCESSFULLY." `
#         -ForegroundColor Green

#     Write-Host "USBSTOR Start = 4" `
#         -ForegroundColor Green

#     Write-Host ""

# }
# catch {

#     Write-Host ""
#     Write-Host "ERROR: Failed to block USB storage." `
#         -ForegroundColor Red

#     Write-Host $_.Exception.Message `
#         -ForegroundColor Red

#     exit 1
# }



#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

$InstallPath = "C:\ProgramData\Taypro\USBSecurity"
$StateFile = Join-Path $InstallPath "usb-storage-state.json"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host " TAYPRO USB STORAGE BLOCKER"
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""


# ==========================================
# CREATE INSTALLATION DIRECTORY
# ==========================================

if (-not (Test-Path $InstallPath)) {

    New-Item `
        -ItemType Directory `
        -Path $InstallPath `
        -Force | Out-Null
}


# ==========================================
# CHECK REGISTRY PATH
# ==========================================

if (-not (Test-Path $RegistryPath)) {

    throw "USBSTOR registry path not found: $RegistryPath"
}


try {

    # ==========================================
    # READ CURRENT USBSTOR VALUE
    # ==========================================

    $CurrentValue = (
        Get-ItemProperty `
            -Path $RegistryPath `
            -Name "Start" `
            -ErrorAction Stop
    ).Start

    Write-Host "Current USBSTOR Start value: $CurrentValue"


    # ==========================================
    # SAVE ORIGINAL VALUE
    # ==========================================

    if (-not (Test-Path $StateFile)) {

        $State = [PSCustomObject]@{
            OriginalStartValue = [int]$CurrentValue
            ChangedByTaypro     = $true
            ChangedAt           = (Get-Date).ToString(
                "yyyy-MM-dd HH:mm:ss"
            )
        }

        $State |
            ConvertTo-Json |
            Set-Content `
                -Path $StateFile `
                -Encoding UTF8 `
                -Force

        Write-Host "Original USBSTOR state saved."
    }
    else {

        Write-Host "Original USBSTOR state already saved."
    }


    # ==========================================
    # BLOCK USB STORAGE
    # ==========================================

    Write-Host ""
    Write-Host "Setting USBSTOR Start value to 4..."

    Set-ItemProperty `
        -Path $RegistryPath `
        -Name "Start" `
        -Type DWord `
        -Value 4 `
        -ErrorAction Stop


    # ==========================================
    # VERIFY USB STORAGE BLOCK
    # ==========================================

    $NewValue = (
        Get-ItemProperty `
            -Path $RegistryPath `
            -Name "Start" `
            -ErrorAction Stop
    ).Start


    if ([int]$NewValue -ne 4) {

        throw "USBSTOR Start value was not changed to 4. Current value: $NewValue"
    }


    # ==========================================
    # SUCCESS
    # ==========================================

    Write-Host ""
    Write-Host "USB STORAGE BLOCKED SUCCESSFULLY." `
        -ForegroundColor Green

    Write-Host "USBSTOR Start = 4" `
        -ForegroundColor Green

    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "ERROR: Failed to block USB storage." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    # IMPORTANT:
    # Throw the error back to Install.ps1.
    # Do NOT use "exit 1" here.
    throw
}
