# #Requires -RunAsAdministrator

# # ==========================================
# # TAYPRO USB SECURITY INSTALLER
# # ==========================================

# $ErrorActionPreference = "Stop"

# $InstallPath = "C:\ProgramData\Taypro\USBSecurity"
# $TaskName = "Taypro USB Security Monitor"

# Write-Host ""
# Write-Host "==========================================" -ForegroundColor Cyan
# Write-Host " TAYPRO USB SECURITY INSTALLER" -ForegroundColor Cyan
# Write-Host "==========================================" -ForegroundColor Cyan
# Write-Host ""

# # ==========================================
# # CHECK ADMIN
# # ==========================================

# Write-Host "Checking administrator privileges..."

# $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
# $AdminPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

# if (-not $AdminPrincipal.IsInRole(
#     [Security.Principal.WindowsBuiltInRole]::Administrator
# )) {
#     Write-Host ""
#     Write-Host "ERROR: Please run PowerShell as Administrator." -ForegroundColor Red
#     Write-Host ""
#     exit 1
# }

# Write-Host "Administrator privileges confirmed." -ForegroundColor Green

# # ==========================================
# # SOURCE DIRECTORY
# # ==========================================

# $SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Write-Host ""
# Write-Host "Source directory:"
# Write-Host $SourceRoot

# # ==========================================
# # CHECK REQUIRED FILES
# # ==========================================

# Write-Host ""
# Write-Host "Checking installation files..."

# $MonitorScript = Join-Path $SourceRoot "USB-SecurityAlert.ps1"
# $ConfigSource = Join-Path $SourceRoot "config\settings.json"

# if (-not (Test-Path $MonitorScript)) {
#     Write-Host ""
#     Write-Host "ERROR: USB-SecurityAlert.ps1 not found." -ForegroundColor Red
#     Write-Host "Expected: $MonitorScript"
#     exit 1
# }

# if (-not (Test-Path $ConfigSource)) {
#     Write-Host ""
#     Write-Host "ERROR: config\settings.json not found." -ForegroundColor Red
#     Write-Host "Expected: $ConfigSource"
#     exit 1
# }

# Write-Host "Required files found." -ForegroundColor Green

# # ==========================================
# # CREATE DIRECTORY
# # ==========================================

# Write-Host ""
# Write-Host "Creating installation directory..."

# New-Item `
#     -ItemType Directory `
#     -Path $InstallPath `
#     -Force | Out-Null

# # ==========================================
# # COPY FILES
# # ==========================================

# Write-Host ""
# Write-Host "Copying files..."

# $MonitorDestination = Join-Path $InstallPath "USB-SecurityAlert.ps1"
# $ConfigDestination = Join-Path $InstallPath "settings.json"

# Copy-Item `
#     -Path $MonitorScript `
#     -Destination $MonitorDestination `
#     -Force

# Copy-Item `
#     -Path $ConfigSource `
#     -Destination $ConfigDestination `
#     -Force

# Write-Host "Files copied successfully." -ForegroundColor Green

# # ==========================================
# # LOAD CONFIG
# # ==========================================

# Write-Host ""
# Write-Host "Loading configuration..."

# try {
#     $Config = Get-Content `
#         -Path $ConfigDestination `
#         -Raw |
#         ConvertFrom-Json
# }
# catch {
#     Write-Host ""
#     Write-Host "ERROR: Unable to read settings.json." -ForegroundColor Red
#     Write-Host $_.Exception.Message -ForegroundColor Red
#     exit 1
# }

# # ==========================================
# # DISPLAY CONFIG
# # ==========================================

# Write-Host ""
# Write-Host "=========================================="
# Write-Host " SMTP CONFIGURATION"
# Write-Host "=========================================="

# Write-Host "SMTP Server : $($Config.SmtpServer)"
# Write-Host "SMTP Port   : $($Config.SmtpPort)"
# Write-Host "SMTP User   : $($Config.AuthUser)"
# Write-Host "From        : $($Config.From)"
# Write-Host "Alert To    : $($Config.To)"
# Write-Host ""

# # ==========================================
# # REQUEST SMTP PASSWORD
# # ==========================================

# Write-Host "Requesting SMTP password..."

# $Credential = Get-Credential `
#     -UserName $Config.AuthUser `
#     -Message "Enter the Hostinger SMTP password"

# if ($null -eq $Credential) {
#     Write-Host ""
#     Write-Host "ERROR: SMTP credential was not provided." -ForegroundColor Red
#     exit 1
# }

# $PlainPassword = $Credential.GetNetworkCredential().Password

# if ([string]::IsNullOrWhiteSpace($PlainPassword)) {
#     Write-Host ""
#     Write-Host "ERROR: SMTP password cannot be empty." -ForegroundColor Red
#     exit 1
# }

# # ==========================================
# # LOAD WINDOWS DPAPI
# # ==========================================

# Write-Host ""
# Write-Host "Loading Windows DPAPI encryption support..."

# try {
#     # Windows PowerShell 5.1 / .NET Framework
#     Add-Type -AssemblyName System.Security -ErrorAction Stop

#     # Verify that the required types are available
#     $null = [System.Security.Cryptography.ProtectedData]
#     $null = [System.Security.Cryptography.DataProtectionScope]

#     Write-Host "DPAPI loaded successfully." -ForegroundColor Green
# }
# catch {
#     Write-Host ""
#     Write-Host "ERROR: Unable to load Windows DPAPI." -ForegroundColor Red
#     Write-Host ""
#     Write-Host $_.Exception.Message -ForegroundColor Red
#     Write-Host ""
#     Write-Host "PowerShell Version : $($PSVersionTable.PSVersion)"
#     Write-Host "PowerShell Edition : $($PSVersionTable.PSEdition)"
#     Write-Host "CLR Version        : $([Environment]::Version)"
#     Write-Host ""

#     $PlainPassword = $null
#     exit 1
# }

# # ==========================================
# # ENCRYPT PASSWORD USING MACHINE DPAPI
# # ==========================================

# Write-Host ""
# Write-Host "Encrypting SMTP credential..."

# try {
#     $PasswordBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainPassword)

#     $EncryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
#         $PasswordBytes,
#         $null,
#         [System.Security.Cryptography.DataProtectionScope]::LocalMachine
#     )

#     $EncryptedPassword = [Convert]::ToBase64String($EncryptedBytes)

#     Write-Host "SMTP credential encrypted successfully." -ForegroundColor Green
# }
# catch {
#     Write-Host ""
#     Write-Host "ERROR: Failed to encrypt SMTP credential." -ForegroundColor Red
#     Write-Host $_.Exception.Message -ForegroundColor Red

#     $PlainPassword = $null
#     $PasswordBytes = $null
#     exit 1
# }

# # ==========================================
# # SAVE ENCRYPTED PASSWORD
# # ==========================================

# $CredentialFile = Join-Path $InstallPath "smtp-secret.dat"

# Write-Host ""
# Write-Host "Saving encrypted SMTP credential..."

# Set-Content `
#     -Path $CredentialFile `
#     -Value $EncryptedPassword `
#     -Encoding ASCII `
#     -Force

# Write-Host "Encrypted credential saved." -ForegroundColor Green

# # ==========================================
# # CLEAR PASSWORD VARIABLES
# # ==========================================

# $PlainPassword = $null
# $PasswordBytes = $null
# $EncryptedBytes = $null
# $EncryptedPassword = $null
# $Credential = $null

# # ==========================================
# # SET DIRECTORY PERMISSIONS
# # ==========================================

# Write-Host ""
# Write-Host "Applying security permissions..."

# icacls $InstallPath /inheritance:r | Out-Null

# icacls $InstallPath `
#     /grant "SYSTEM:(OI)(CI)(F)" | Out-Null

# icacls $InstallPath `
#     /grant "Administrators:(OI)(CI)(F)" | Out-Null

# icacls $InstallPath `
#     /remove "Users" | Out-Null

# icacls $InstallPath `
#     /remove "Authenticated Users" | Out-Null

# Write-Host "Directory permissions configured." -ForegroundColor Green

# # ==========================================
# # PROTECT MONITOR SCRIPT
# # ==========================================

# Write-Host ""
# Write-Host "Protecting USB monitor script..."

# icacls $MonitorDestination /inheritance:r | Out-Null

# icacls $MonitorDestination `
#     /grant "SYSTEM:(F)" `
#     /grant "Administrators:(F)" | Out-Null

# # ==========================================
# # PROTECT CONFIG
# # ==========================================

# Write-Host "Protecting settings.json..."

# icacls $ConfigDestination /inheritance:r | Out-Null

# icacls $ConfigDestination `
#     /grant "SYSTEM:(F)" `
#     /grant "Administrators:(F)" | Out-Null

# # ==========================================
# # PROTECT SMTP SECRET
# # ==========================================

# Write-Host "Protecting SMTP credential..."

# icacls $CredentialFile /inheritance:r | Out-Null

# icacls $CredentialFile `
#     /grant "SYSTEM:(F)" `
#     /grant "Administrators:(F)" | Out-Null

# # ==========================================
# # CREATE LOG FILE
# # ==========================================

# $LogFile = Join-Path $InstallPath "USBSecurity.log"

# Write-Host ""
# Write-Host "Creating log file..."

# if (-not (Test-Path $LogFile)) {
#     New-Item `
#         -ItemType File `
#         -Path $LogFile `
#         -Force | Out-Null
# }

# icacls $LogFile /inheritance:r | Out-Null

# icacls $LogFile `
#     /grant "SYSTEM:(F)" `
#     /grant "Administrators:(F)" | Out-Null

# Write-Host "Log file created." -ForegroundColor Green

# # ==========================================
# # REMOVE OLD SCHEDULED TASK
# # ==========================================

# Write-Host ""
# Write-Host "Removing existing scheduled task if present..."

# $ExistingTask = Get-ScheduledTask `
#     -TaskName $TaskName `
#     -ErrorAction SilentlyContinue

# if ($null -ne $ExistingTask) {
#     Stop-ScheduledTask `
#         -TaskName $TaskName `
#         -ErrorAction SilentlyContinue

#     Unregister-ScheduledTask `
#         -TaskName $TaskName `
#         -Confirm:$false `
#         -ErrorAction SilentlyContinue

#     Write-Host "Existing task removed." -ForegroundColor Yellow
# }
# else {
#     Write-Host "No existing task found."
# }

# # ==========================================
# # CREATE STARTUP TASK
# # ==========================================

# Write-Host ""
# Write-Host "Creating Windows startup task..."

# $PowerShellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

# $Action = New-ScheduledTaskAction `
#     -Execute $PowerShellPath `
#     -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MonitorDestination`""

# $Trigger = New-ScheduledTaskTrigger `
#     -AtStartup

# $TaskPrincipal = New-ScheduledTaskPrincipal `
#     -UserId "SYSTEM" `
#     -LogonType ServiceAccount `
#     -RunLevel Highest

# $Settings = New-ScheduledTaskSettingsSet `
#     -StartWhenAvailable `
#     -RestartCount 3 `
#     -RestartInterval (New-TimeSpan -Minutes 1)

# Register-ScheduledTask `
#     -TaskName $TaskName `
#     -Action $Action `
#     -Trigger $Trigger `
#     -Principal $TaskPrincipal `
#     -Settings $Settings `
#     -Description "Taypro USB Security Monitor" `
#     -Force | Out-Null

# Write-Host "Scheduled task created successfully." -ForegroundColor Green

# # ==========================================
# # START MONITOR NOW
# # ==========================================

# Write-Host ""
# Write-Host "Starting USB Security Monitor..."

# Start-ScheduledTask `
#     -TaskName $TaskName

# Start-Sleep -Seconds 5

# # ==========================================
# # VERIFY TASK
# # ==========================================

# Write-Host ""
# Write-Host "Verifying scheduled task..."

# $Task = Get-ScheduledTask `
#     -TaskName $TaskName `
#     -ErrorAction SilentlyContinue

# if ($null -eq $Task) {
#     Write-Host ""
#     Write-Host "ERROR: Scheduled task was not created." -ForegroundColor Red
#     exit 1
# }

# $TaskInfo = Get-ScheduledTaskInfo `
#     -TaskName $TaskName `
#     -ErrorAction SilentlyContinue

# # ==========================================
# # INSTALLATION COMPLETE
# # ==========================================

# Write-Host ""
# Write-Host "==========================================" -ForegroundColor Green
# Write-Host " INSTALLATION COMPLETED" -ForegroundColor Green
# Write-Host "==========================================" -ForegroundColor Green
# Write-Host ""

# Write-Host "Installation : $InstallPath"
# Write-Host "Monitor      : $MonitorDestination"
# Write-Host "Config       : $ConfigDestination"
# Write-Host "Credential   : $CredentialFile"
# Write-Host "Log          : $LogFile"
# Write-Host "Task         : $TaskName"
# Write-Host "Task User    : SYSTEM"
# Write-Host "Task State   : $($Task.State)"

# if ($null -ne $TaskInfo) {
#     Write-Host "Last Run     : $($TaskInfo.LastRunTime)"
#     Write-Host "Last Result  : $($TaskInfo.LastTaskResult)"
# }

# Write-Host ""

# # ==========================================
# # SHOW LOG
# # ==========================================

# if (Test-Path $LogFile) {
#     Write-Host "Recent USB Security log:" -ForegroundColor Cyan
#     Write-Host "------------------------------------------"

#     Get-Content `
#         -Path $LogFile `
#         -Tail 10

#     Write-Host "------------------------------------------"
# }

# Write-Host ""
# Write-Host "USB Security Monitor is now active." -ForegroundColor Green
# Write-Host ""


#Requires -RunAsAdministrator

# ==========================================
# TAYPRO USB SECURITY INSTALLER
# ==========================================

$ErrorActionPreference = "Stop"

$InstallPath = "C:\ProgramData\Taypro\USBSecurity"
$TaskName = "Taypro USB Security Monitor"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TAYPRO USB SECURITY INSTALLER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ==========================================
# CHECK ADMIN
# ==========================================

Write-Host "Checking administrator privileges..."

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$AdminPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

if (-not $AdminPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Host ""
    Write-Host "ERROR: Please run PowerShell as Administrator." -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host "Administrator privileges confirmed." -ForegroundColor Green

# ==========================================
# SOURCE DIRECTORY
# ==========================================

$SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "Source directory:"
Write-Host $SourceRoot

# ==========================================
# CHECK REQUIRED FILES
# ==========================================

Write-Host ""
Write-Host "Checking installation files..."

$MonitorScript = Join-Path $SourceRoot "USB-SecurityAlert.ps1"
$ConfigSource = Join-Path $SourceRoot "config\settings.json"
$BlockUSBScript = Join-Path $SourceRoot "Block-USBStorage.ps1"

if (-not (Test-Path $MonitorScript)) {
    Write-Host ""
    Write-Host "ERROR: USB-SecurityAlert.ps1 not found." -ForegroundColor Red
    Write-Host "Expected: $MonitorScript"
    exit 1
}

if (-not (Test-Path $ConfigSource)) {
    Write-Host ""
    Write-Host "ERROR: config\settings.json not found." -ForegroundColor Red
    Write-Host "Expected: $ConfigSource"
    exit 1
}

if (-not (Test-Path $BlockUSBScript)) {
    Write-Host ""
    Write-Host "ERROR: Block-USBStorage.ps1 not found." -ForegroundColor Red
    Write-Host "Expected: $BlockUSBScript"
    exit 1
}

Write-Host "Required files found." -ForegroundColor Green

# ==========================================
# STEP 0 - BLOCK USB STORAGE
# ==========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host " STEP 0: BLOCKING USB STORAGE"
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""

Write-Host "Running Block-USBStorage.ps1..."

try {

    # Run the USB blocking script
    & $BlockUSBScript

    Write-Host ""
    Write-Host "Block-USBStorage.ps1 completed." `
        -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "ERROR: USB storage blocking failed." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}


# ==========================================
# VERIFY USBSTOR
# ==========================================

$USBStorRegistryPath = `
    "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

try {

    $USBStorStart = (
        Get-ItemProperty `
            -Path $USBStorRegistryPath `
            -Name "Start" `
            -ErrorAction Stop
    ).Start

    if ([int]$USBStorStart -ne 4) {

        throw "USBSTOR Start value is $USBStorStart instead of 4."
    }

    Write-Host ""
    Write-Host "USB STORAGE BLOCKED SUCCESSFULLY." `
        -ForegroundColor Green

    Write-Host "USBSTOR Start = 4" `
        -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "ERROR: USB storage block verification failed." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 1
}

# ==========================================
# CREATE DIRECTORY
# ==========================================

Write-Host ""
Write-Host "Creating installation directory..."

New-Item `
    -ItemType Directory `
    -Path $InstallPath `
    -Force | Out-Null

# ==========================================
# COPY FILES
# ==========================================

Write-Host ""
Write-Host "Copying files..."

$MonitorDestination = Join-Path $InstallPath "USB-SecurityAlert.ps1"
$ConfigDestination = Join-Path $InstallPath "settings.json"

Copy-Item `
    -Path $MonitorScript `
    -Destination $MonitorDestination `
    -Force

Copy-Item `
    -Path $ConfigSource `
    -Destination $ConfigDestination `
    -Force

Write-Host "Files copied successfully." -ForegroundColor Green

# ==========================================
# LOAD CONFIG
# ==========================================

Write-Host ""
Write-Host "Loading configuration..."

try {
    $Config = Get-Content `
        -Path $ConfigDestination `
        -Raw |
        ConvertFrom-Json
}
catch {
    Write-Host ""
    Write-Host "ERROR: Unable to read settings.json." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ==========================================
# DISPLAY CONFIG
# ==========================================

Write-Host ""
Write-Host "=========================================="
Write-Host " SMTP CONFIGURATION"
Write-Host "=========================================="

Write-Host "SMTP Server : $($Config.SmtpServer)"
Write-Host "SMTP Port   : $($Config.SmtpPort)"
Write-Host "SMTP User   : $($Config.AuthUser)"
Write-Host "From        : $($Config.From)"
Write-Host "Alert To    : $($Config.To)"
Write-Host ""

# ==========================================
# REQUEST SMTP PASSWORD
# ==========================================

Write-Host "Requesting SMTP password..."

$Credential = Get-Credential `
    -UserName $Config.AuthUser `
    -Message "Enter the Hostinger SMTP password"

if ($null -eq $Credential) {
    Write-Host ""
    Write-Host "ERROR: SMTP credential was not provided." -ForegroundColor Red
    exit 1
}

$PlainPassword = $Credential.GetNetworkCredential().Password

if ([string]::IsNullOrWhiteSpace($PlainPassword)) {
    Write-Host ""
    Write-Host "ERROR: SMTP password cannot be empty." -ForegroundColor Red
    exit 1
}

# ==========================================
# LOAD WINDOWS DPAPI
# ==========================================

Write-Host ""
Write-Host "Loading Windows DPAPI encryption support..."

try {
    # Windows PowerShell 5.1 / .NET Framework
    Add-Type -AssemblyName System.Security -ErrorAction Stop

    # Verify that the required types are available
    $null = [System.Security.Cryptography.ProtectedData]
    $null = [System.Security.Cryptography.DataProtectionScope]

    Write-Host "DPAPI loaded successfully." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "ERROR: Unable to load Windows DPAPI." -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "PowerShell Version : $($PSVersionTable.PSVersion)"
    Write-Host "PowerShell Edition : $($PSVersionTable.PSEdition)"
    Write-Host "CLR Version        : $([Environment]::Version)"
    Write-Host ""

    $PlainPassword = $null
    exit 1
}

# ==========================================
# ENCRYPT PASSWORD USING MACHINE DPAPI
# ==========================================

Write-Host ""
Write-Host "Encrypting SMTP credential..."

try {
    $PasswordBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainPassword)

    $EncryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $PasswordBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::LocalMachine
    )

    $EncryptedPassword = [Convert]::ToBase64String($EncryptedBytes)

    Write-Host "SMTP credential encrypted successfully." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "ERROR: Failed to encrypt SMTP credential." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $PlainPassword = $null
    $PasswordBytes = $null
    exit 1
}

# ==========================================
# SAVE ENCRYPTED PASSWORD
# ==========================================

$CredentialFile = Join-Path $InstallPath "smtp-secret.dat"

Write-Host ""
Write-Host "Saving encrypted SMTP credential..."

Set-Content `
    -Path $CredentialFile `
    -Value $EncryptedPassword `
    -Encoding ASCII `
    -Force

Write-Host "Encrypted credential saved." -ForegroundColor Green

# ==========================================
# CLEAR PASSWORD VARIABLES
# ==========================================

$PlainPassword = $null
$PasswordBytes = $null
$EncryptedBytes = $null
$EncryptedPassword = $null
$Credential = $null

# ==========================================
# SET DIRECTORY PERMISSIONS
# ==========================================

Write-Host ""
Write-Host "Applying security permissions..."

icacls $InstallPath /inheritance:r | Out-Null

icacls $InstallPath `
    /grant "SYSTEM:(OI)(CI)(F)" | Out-Null

icacls $InstallPath `
    /grant "Administrators:(OI)(CI)(F)" | Out-Null

icacls $InstallPath `
    /remove "Users" | Out-Null

icacls $InstallPath `
    /remove "Authenticated Users" | Out-Null

Write-Host "Directory permissions configured." -ForegroundColor Green

# ==========================================
# PROTECT MONITOR SCRIPT
# ==========================================

Write-Host ""
Write-Host "Protecting USB monitor script..."

icacls $MonitorDestination /inheritance:r | Out-Null

icacls $MonitorDestination `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

# ==========================================
# PROTECT CONFIG
# ==========================================

Write-Host "Protecting settings.json..."

icacls $ConfigDestination /inheritance:r | Out-Null

icacls $ConfigDestination `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

# ==========================================
# PROTECT SMTP SECRET
# ==========================================

Write-Host "Protecting SMTP credential..."

icacls $CredentialFile /inheritance:r | Out-Null

icacls $CredentialFile `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

# ==========================================
# CREATE LOG FILE
# ==========================================

$LogFile = Join-Path $InstallPath "USBSecurity.log"

Write-Host ""
Write-Host "Creating log file..."

if (-not (Test-Path $LogFile)) {
    New-Item `
        -ItemType File `
        -Path $LogFile `
        -Force | Out-Null
}

icacls $LogFile /inheritance:r | Out-Null

icacls $LogFile `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

Write-Host "Log file created." -ForegroundColor Green

# ==========================================
# REMOVE OLD SCHEDULED TASK
# ==========================================

Write-Host ""
Write-Host "Removing existing scheduled task if present..."

$ExistingTask = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

if ($null -ne $ExistingTask) {
    Stop-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction SilentlyContinue

    Unregister-ScheduledTask `
        -TaskName $TaskName `
        -Confirm:$false `
        -ErrorAction SilentlyContinue

    Write-Host "Existing task removed." -ForegroundColor Yellow
}
else {
    Write-Host "No existing task found."
}

# ==========================================
# CREATE STARTUP TASK
# ==========================================

Write-Host ""
Write-Host "Creating Windows startup task..."

$PowerShellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

$Action = New-ScheduledTaskAction `
    -Execute $PowerShellPath `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MonitorDestination`""

$Trigger = New-ScheduledTaskTrigger `
    -AtStartup

$TaskPrincipal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $TaskPrincipal `
    -Settings $Settings `
    -Description "Taypro USB Security Monitor" `
    -Force | Out-Null

Write-Host "Scheduled task created successfully." -ForegroundColor Green

# ==========================================
# START MONITOR NOW
# ==========================================

Write-Host ""
Write-Host "Starting USB Security Monitor..."

Start-ScheduledTask `
    -TaskName $TaskName

Start-Sleep -Seconds 5

# ==========================================
# VERIFY TASK
# ==========================================

Write-Host ""
Write-Host "Verifying scheduled task..."

$Task = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

if ($null -eq $Task) {
    Write-Host ""
    Write-Host "ERROR: Scheduled task was not created." -ForegroundColor Red
    exit 1
}

$TaskInfo = Get-ScheduledTaskInfo `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

# ==========================================
# INSTALLATION COMPLETE
# ==========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " INSTALLATION COMPLETED" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "USB Storage  : BLOCKED (USBSTOR Start = 4)"
Write-Host "Installation : $InstallPath"
Write-Host "Monitor      : $MonitorDestination"
Write-Host "Config       : $ConfigDestination"
Write-Host "Credential   : $CredentialFile"
Write-Host "Log          : $LogFile"
Write-Host "Task         : $TaskName"
Write-Host "Task User    : SYSTEM"
Write-Host "Task State   : $($Task.State)"

if ($null -ne $TaskInfo) {
    Write-Host "Last Run     : $($TaskInfo.LastRunTime)"
    Write-Host "Last Result  : $($TaskInfo.LastTaskResult)"
}

Write-Host ""

# ==========================================
# SHOW LOG
# ==========================================

if (Test-Path $LogFile) {
    Write-Host "Recent USB Security log:" -ForegroundColor Cyan
    Write-Host "------------------------------------------"

    Get-Content `
        -Path $LogFile `
        -Tail 10

    Write-Host "------------------------------------------"
}

Write-Host ""
Write-Host "USB Security Monitor is now active." -ForegroundColor Green
Write-Host ""
