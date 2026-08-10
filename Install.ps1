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
# CREATE DIRECTORY
# ==========================================

Write-Host "Creating installation directory..."

New-Item `
    -ItemType Directory `
    -Path $InstallPath `
    -Force | Out-Null

# ==========================================
# COPY FILES
# ==========================================

$SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Copy-Item `
    "$SourceRoot\USB-SecurityAlert.ps1" `
    "$InstallPath\USB-SecurityAlert.ps1" `
    -Force

Copy-Item `
    "$SourceRoot\config\settings.json" `
    "$InstallPath\settings.json" `
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
# REQUEST SMTP PASSWORD
# ==========================================

$Credential = Get-Credential `
    -UserName $Config.AuthUser `
    -Message "Enter the Hostinger SMTP password"

$PlainPassword = $Credential.GetNetworkCredential().Password

# ==========================================
# ENCRYPT PASSWORD USING MACHINE DPAPI
# ==========================================

Write-Host ""
Write-Host "Encrypting SMTP credential..."

$PasswordBytes = [System.Text.Encoding]::UTF8.GetBytes(
    $PlainPassword
)

$EncryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
    $PasswordBytes,
    $null,
    [System.Security.Cryptography.DataProtectionScope]::LocalMachine
)

$EncryptedPassword = [Convert]::ToBase64String(
    $EncryptedBytes
)

$CredentialFile = "$InstallPath\smtp-secret.dat"

Set-Content `
    -Path $CredentialFile `
    -Value $EncryptedPassword `
    -Encoding ASCII

# Clear password variable

$PlainPassword = $null
$PasswordBytes = $null

# ==========================================
# SET FILE PERMISSIONS
# ==========================================

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

# ==========================================
# PROTECT INDIVIDUAL FILES
# ==========================================

icacls "$InstallPath\USB-SecurityAlert.ps1" `
    /inheritance:r | Out-Null

icacls "$InstallPath\USB-SecurityAlert.ps1" `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

icacls "$InstallPath\settings.json" `
    /inheritance:r | Out-Null

icacls "$InstallPath\settings.json" `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

icacls "$InstallPath\smtp-secret.dat" `
    /inheritance:r | Out-Null

icacls "$InstallPath\smtp-secret.dat" `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

# ==========================================
# CREATE LOG FILE
# ==========================================

$LogFile = "$InstallPath\USBSecurity.log"

if (!(Test-Path $LogFile)) {

    New-Item `
        -ItemType File `
        -Path $LogFile `
        -Force | Out-Null
}

icacls $LogFile `
    /inheritance:r | Out-Null

icacls $LogFile `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" | Out-Null

# ==========================================
# REMOVE OLD TASK
# ==========================================

Unregister-ScheduledTask `
    -TaskName $TaskName `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

# ==========================================
# CREATE STARTUP TASK
# ==========================================

Write-Host "Creating Windows startup task..."

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$InstallPath\USB-SecurityAlert.ps1`""

$Trigger = New-ScheduledTaskTrigger `
    -AtStartup

$Principal = New-ScheduledTaskPrincipal `
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
    -Principal $Principal `
    -Settings $Settings `
    -Description "Taypro USB Security Monitor" `
    -Force | Out-Null

# ==========================================
# START NOW
# ==========================================

Write-Host "Starting USB monitor..."

Start-ScheduledTask `
    -TaskName $TaskName

Start-Sleep -Seconds 3

# ==========================================
# VERIFY
# ==========================================

$Task = Get-ScheduledTask `
    -TaskName $TaskName

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " INSTALLATION COMPLETED" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Installation : $InstallPath"
Write-Host "Task         : $TaskName"
Write-Host "Task User    : SYSTEM"
Write-Host "State        : $($Task.State)"
Write-Host ""

Write-Host "USB Security Monitor is now active." -ForegroundColor Green
Write-Host ""