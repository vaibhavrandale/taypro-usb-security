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





 #========================================== ========================================== ========================================== ========================================== ==========================================


#Requires -RunAsAdministrator

# ==========================================
# TAYPRO USB SECURITY INSTALLER
# ==========================================


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
# $BlockUSBScript = Join-Path $SourceRoot "Block-USBStorage.ps1"

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

# if (-not (Test-Path $BlockUSBScript)) {
#     Write-Host ""
#     Write-Host "ERROR: Block-USBStorage.ps1 not found." -ForegroundColor Red
#     Write-Host "Expected: $BlockUSBScript"
#     exit 1
# }

# Write-Host "Required files found." -ForegroundColor Green

# # ==========================================
# # STEP 0 - BLOCK USB STORAGE
# # ==========================================

# Write-Host ""
# Write-Host "==========================================" -ForegroundColor Yellow
# Write-Host " STEP 0: BLOCKING USB STORAGE"
# Write-Host "==========================================" -ForegroundColor Yellow
# Write-Host ""

# Write-Host "Running Block-USBStorage.ps1..."

# try {

#     # Run the USB blocking script
#     & $BlockUSBScript

#     Write-Host ""
#     Write-Host "Block-USBStorage.ps1 completed." `
#         -ForegroundColor Green

# }
# catch {

#     Write-Host ""
#     Write-Host "ERROR: USB storage blocking failed." `
#         -ForegroundColor Red

#     Write-Host $_.Exception.Message `
#         -ForegroundColor Red

#     exit 1
# }


# # ==========================================
# # VERIFY USBSTOR
# # ==========================================

# $USBStorRegistryPath = `
#     "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR"

# try {

#     $USBStorStart = (
#         Get-ItemProperty `
#             -Path $USBStorRegistryPath `
#             -Name "Start" `
#             -ErrorAction Stop
#     ).Start

#     if ([int]$USBStorStart -ne 4) {

#         throw "USBSTOR Start value is $USBStorStart instead of 4."
#     }

#     Write-Host ""
#     Write-Host "USB STORAGE BLOCKED SUCCESSFULLY." `
#         -ForegroundColor Green

#     Write-Host "USBSTOR Start = 4" `
#         -ForegroundColor Green

# }
# catch {

#     Write-Host ""
#     Write-Host "ERROR: USB storage block verification failed." `
#         -ForegroundColor Red

#     Write-Host $_.Exception.Message `
#         -ForegroundColor Red

#     exit 1
# }

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

# Write-Host "USB Storage  : BLOCKED (USBSTOR Start = 4)"
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

 #========================================== ========================================== ========================================== ========================================== ==========================================




#Requires -RunAsAdministrator
#Requires -Version 5.1

# ==========================================
# TAYPRO USB SECURITY INSTALLER
# ==========================================

$ErrorActionPreference = "Stop"

$InstallPath = "C:\ProgramData\Taypro\USBSecurity"
$TaskName    = "Taypro USB Security Monitor"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " TAYPRO USB SECURITY INSTALLER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ==========================================
# ADMIN CHECK
# ==========================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

$AdminPrincipal = New-Object `
    Security.Principal.WindowsPrincipal(
        $CurrentIdentity
    )

if (-not $AdminPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {

    Write-Host "ERROR: Please run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

# ==========================================
# SOURCE PATH
# ==========================================

$SourceRoot = Split-Path `
    -Parent `
    $MyInvocation.MyCommand.Path

$MonitorSource = Join-Path `
    $SourceRoot `
    "USB-SecurityAlert.ps1"

$ConfigSource = Join-Path `
    $SourceRoot `
    "config\settings.json"

$BlockerSource = Join-Path `
    $SourceRoot `
    "Block-USBStorage.ps1"

if (-not (Test-Path $MonitorSource)) {
    throw "USB-SecurityAlert.ps1 not found: $MonitorSource"
}

if (-not (Test-Path $ConfigSource)) {
    throw "settings.json not found: $ConfigSource"
}

if (-not (Test-Path $BlockerSource)) {
    throw "Block-USBStorage.ps1 not found: $BlockerSource"
}

# ==========================================
# CREATE INSTALLATION DIRECTORY
# ==========================================

Write-Host "Creating installation directory..."

New-Item `
    -ItemType Directory `
    -Path $InstallPath `
    -Force |
    Out-Null

# ==========================================
# STOP OLD TASK
# ==========================================

Write-Host "Stopping previous monitor..."

Stop-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# ==========================================
# STOP OLD MONITOR PROCESSES
# ==========================================

$OldProcesses = Get-CimInstance Win32_Process |
    Where-Object {

        $_.Name -eq "powershell.exe" -and
        $_.CommandLine -like "*USB-SecurityAlert.ps1*"
    }

foreach ($Process in $OldProcesses) {

    Write-Host "Stopping old monitor PID $($Process.ProcessId)..."

    Stop-Process `
        -Id $Process.ProcessId `
        -Force `
        -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 2

# ==========================================
# COPY MONITOR
# ==========================================

Write-Host "Installing USB security monitor..."

Copy-Item `
    -Path $MonitorSource `
    -Destination "$InstallPath\USB-SecurityAlert.ps1" `
    -Force

# ==========================================
# COPY CONFIG
# ==========================================

Copy-Item `
    -Path $ConfigSource `
    -Destination "$InstallPath\settings.json" `
    -Force

# ==========================================
# COPY USB BLOCKER
# ==========================================

Copy-Item `
    -Path $BlockerSource `
    -Destination "$InstallPath\Block-USBStorage.ps1" `
    -Force

# ==========================================
# LOAD CONFIG
# ==========================================

$Config = Get-Content `
    "$InstallPath\settings.json" `
    -Raw |
    ConvertFrom-Json

Write-Host ""
Write-Host "SMTP Server : $($Config.SmtpServer)"
Write-Host "SMTP Port   : $($Config.SmtpPort)"
Write-Host "SMTP User   : $($Config.AuthUser)"
Write-Host "From        : $($Config.From)"
Write-Host "Alert To    : $($Config.To)"
Write-Host ""

# ==========================================
# NATIVE WINDOWS DPAPI
# ==========================================

Write-Host "Loading native Windows DPAPI..."

if (-not ("TayproNativeDPAPI" -as [type])) {

    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class TayproNativeDPAPI
{
    [StructLayout(LayoutKind.Sequential)]
    public struct DATA_BLOB
    {
        public int cbData;
        public IntPtr pbData;
    }

    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CryptProtectData(
        ref DATA_BLOB pDataIn,
        string szDataDescr,
        IntPtr pOptionalEntropy,
        IntPtr pvReserved,
        IntPtr pPromptStruct,
        uint dwFlags,
        out DATA_BLOB pDataOut
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LocalFree(IntPtr hMem);

    private const uint CRYPTPROTECT_LOCAL_MACHINE = 0x4;

    public static byte[] Protect(byte[] plainBytes)
    {
        DATA_BLOB input = new DATA_BLOB();
        DATA_BLOB output;

        input.cbData = plainBytes.Length;
        input.pbData = Marshal.AllocHGlobal(plainBytes.Length);

        try
        {
            Marshal.Copy(
                plainBytes,
                0,
                input.pbData,
                plainBytes.Length
            );

            bool result = CryptProtectData(
                ref input,
                "Taypro USB Security SMTP Credential",
                IntPtr.Zero,
                IntPtr.Zero,
                IntPtr.Zero,
                CRYPTPROTECT_LOCAL_MACHINE,
                out output
            );

            if (!result)
            {
                throw new System.ComponentModel.Win32Exception(
                    Marshal.GetLastWin32Error()
                );
            }

            byte[] encrypted = new byte[output.cbData];

            Marshal.Copy(
                output.pbData,
                encrypted,
                0,
                output.cbData
            );

            LocalFree(output.pbData);

            return encrypted;
        }
        finally
        {
            if (input.pbData != IntPtr.Zero)
            {
                Marshal.FreeHGlobal(input.pbData);
            }
        }
    }
}
"@
}

Write-Host "DPAPI loaded successfully." -ForegroundColor Green

# ==========================================
# REQUEST SMTP PASSWORD
# ==========================================

Write-Host ""
Write-Host "Enter the Hostinger SMTP password." -ForegroundColor Yellow

$SecurePassword = Read-Host `
    "SMTP Password" `
    -AsSecureString

# Convert SecureString to plaintext only temporarily
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
    $SecurePassword
)

try {

    $PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
        $BSTR
    )
}
finally {

    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
        $BSTR
    )
}

if ([string]::IsNullOrWhiteSpace($PlainPassword)) {
    throw "SMTP password cannot be empty."
}

# ==========================================
# ENCRYPT SMTP PASSWORD
# ==========================================

Write-Host ""
Write-Host "Encrypting SMTP credential..."

$PasswordBytes = [System.Text.Encoding]::UTF8.GetBytes(
    $PlainPassword
)

$EncryptedBytes = [TayproNativeDPAPI]::Protect(
    $PasswordBytes
)

$EncryptedPassword = [Convert]::ToBase64String(
    $EncryptedBytes
)

$CredentialFile = Join-Path `
    $InstallPath `
    "smtp-secret.dat"

Set-Content `
    -Path $CredentialFile `
    -Value $EncryptedPassword `
    -Encoding ASCII

Write-Host "SMTP credential encrypted successfully." -ForegroundColor Green

# Clear temporary password data
$PlainPassword = $null
$PasswordBytes = $null
$EncryptedBytes = $null
$EncryptedPassword = $null
$SecurePassword = $null

# ==========================================
# FILE PERMISSIONS
# ==========================================

Write-Host ""
Write-Host "Applying security permissions..."

icacls $InstallPath /inheritance:r | Out-Null

icacls $InstallPath `
    /grant "SYSTEM:(OI)(CI)(F)" |
    Out-Null

icacls $InstallPath `
    /grant "Administrators:(OI)(CI)(F)" |
    Out-Null

icacls $InstallPath `
    /remove "Users" |
    Out-Null

icacls $InstallPath `
    /remove "Authenticated Users" |
    Out-Null

# ==========================================
# PROTECT FILES
# ==========================================

$FilesToProtect = @(
    "$InstallPath\USB-SecurityAlert.ps1",
    "$InstallPath\settings.json",
    "$InstallPath\Block-USBStorage.ps1",
    "$InstallPath\smtp-secret.dat"
)

foreach ($File in $FilesToProtect) {

    if (Test-Path $File) {

        icacls $File /inheritance:r | Out-Null

        icacls $File `
            /grant "SYSTEM:(F)" `
            /grant "Administrators:(F)" |
            Out-Null
    }
}

# ==========================================
# CREATE LOG
# ==========================================

$LogFile = "$InstallPath\USBSecurity.log"

if (-not (Test-Path $LogFile)) {

    New-Item `
        -ItemType File `
        -Path $LogFile `
        -Force |
        Out-Null
}

icacls $LogFile /inheritance:r | Out-Null

icacls $LogFile `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" |
    Out-Null

# ==========================================
# INSTALL USB BLOCKER
# ==========================================

Write-Host ""
Write-Host "Configuring USB storage blocking..." -ForegroundColor Yellow

try {

    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File "$InstallPath\Block-USBStorage.ps1"

    Write-Host "USB storage blocking configured." -ForegroundColor Green

}
catch {

    Write-Host "WARNING: USB blocker returned an error:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message
}

# ==========================================
# REMOVE OLD TASK
# ==========================================

Write-Host ""
Write-Host "Removing previous scheduled task..."

Unregister-ScheduledTask `
    -TaskName $TaskName `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# ==========================================
# CREATE TASK ACTION
# ==========================================

$PowerShellPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"

$MonitorPath = "$InstallPath\USB-SecurityAlert.ps1"

$Action = New-ScheduledTaskAction `
    -Execute $PowerShellPath `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MonitorPath`""

# ==========================================
# STARTUP TRIGGER
# ==========================================

$Trigger = New-ScheduledTaskTrigger `
    -AtStartup

# ==========================================
# SYSTEM PRINCIPAL
# ==========================================

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# ==========================================
# TASK SETTINGS
# ==========================================

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

# ==========================================
# REGISTER TASK
# ==========================================

Write-Host ""
Write-Host "Creating Windows startup task..."

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Description "Taypro USB Security Monitor" `
    -Force |
    Out-Null

Write-Host "Scheduled task created successfully." -ForegroundColor Green

# ==========================================
# START NOW
# ==========================================

Write-Host ""
Write-Host "Starting USB Security Monitor..."

Start-ScheduledTask `
    -TaskName $TaskName

Start-Sleep -Seconds 8

# ==========================================
# VERIFY TASK
# ==========================================

$Task = Get-ScheduledTask `
    -TaskName $TaskName

$TaskInfo = Get-ScheduledTaskInfo `
    -TaskName $TaskName

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " INSTALLATION COMPLETED" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Installation : $InstallPath"
Write-Host "Task         : $TaskName"
Write-Host "Task User    : $($Task.Principal.UserId)"
Write-Host "Run Level    : $($Task.Principal.RunLevel)"
Write-Host "State        : $($Task.State)"
Write-Host "Last Result  : $($TaskInfo.LastTaskResult)"
Write-Host ""

# ==========================================
# VERIFY PROCESS
# ==========================================

$MonitorProcess = Get-CimInstance Win32_Process |
    Where-Object {

        $_.Name -eq "powershell.exe" -and
        $_.CommandLine -like "*USB-SecurityAlert.ps1*"
    }

if ($MonitorProcess) {

    Write-Host "USB Security Monitor process is RUNNING." `
        -ForegroundColor Green

}
else {

    Write-Host "WARNING: USB Security Monitor process was not found." `
        -ForegroundColor Yellow
}

# ==========================================
# LOG
# ==========================================

Write-Host ""
Write-Host "Latest monitor log:" -ForegroundColor Cyan

if (Test-Path $LogFile) {

    Get-Content `
        $LogFile `
        -Tail 15
}

Write-Host ""
Write-Host "USB Security Monitor is now active." `
    -ForegroundColor Green

Write-Host ""

