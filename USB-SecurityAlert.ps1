# ==========================================
# TAYPRO USB SECURITY MONITOR
# ==========================================

$ErrorActionPreference = "Stop"

$BasePath       = "C:\ProgramData\Taypro\USBSecurity"
$ConfigFile     = Join-Path $BasePath "settings.json"
$CredentialFile = Join-Path $BasePath "smtp-secret.dat"
$LogFile        = Join-Path $BasePath "USBSecurity.log"

# ==========================================
# ENSURE BASE DIRECTORY EXISTS
# ==========================================

if (-not (Test-Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
}

# ==========================================
# LOG FUNCTION
# ==========================================

function Write-Log {
    param(
        [string]$Message
    )

    try {
        $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "[$Time] $Message"
    }
    catch {
        # Do not terminate the USB monitor because logging failed.
    }
}

# ==========================================
# STARTUP
# ==========================================

Write-Log "=========================================="
Write-Log "TAYPRO USB SECURITY MONITOR STARTING"
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "Process User: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "PowerShell: $($PSVersionTable.PSVersion)"
Write-Log "=========================================="

# ==========================================
# LOAD WINDOWS DPAPI
# ==========================================

try {
    # Required for Windows PowerShell 5.1.
    Add-Type -AssemblyName System.Security -ErrorAction Stop

    $null = [System.Security.Cryptography.ProtectedData]
    $null = [System.Security.Cryptography.DataProtectionScope]

    Write-Log "DPAPI loaded successfully."
}
catch {
    Write-Log "ERROR loading DPAPI: $($_.Exception.Message)"
    exit 1
}

# ==========================================
# LOAD CONFIGURATION
# ==========================================

if (-not (Test-Path $ConfigFile)) {
    Write-Log "ERROR: settings.json not found."
    exit 1
}

try {
    $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

    $SmtpServer = [string]$Config.SmtpServer
    $SmtpPort   = [int]$Config.SmtpPort
    $From       = [string]$Config.From
    $To         = [string]$Config.To
    $AuthUser   = [string]$Config.AuthUser

    if ([string]::IsNullOrWhiteSpace($SmtpServer)) {
        throw "SMTP server is empty."
    }

    if ($SmtpPort -le 0) {
        throw "SMTP port is invalid."
    }

    if ([string]::IsNullOrWhiteSpace($AuthUser)) {
        throw "SMTP username is empty."
    }

    if ([string]::IsNullOrWhiteSpace($From)) {
        throw "From address is empty."
    }

    if ([string]::IsNullOrWhiteSpace($To)) {
        throw "To address is empty."
    }

    Write-Log "Configuration loaded successfully."
}
catch {
    Write-Log "ERROR loading configuration: $($_.Exception.Message)"
    exit 1
}

# ==========================================
# LOAD ENCRYPTED SMTP PASSWORD
# ==========================================

if (-not (Test-Path $CredentialFile)) {
    Write-Log "ERROR: SMTP credential not found."
    exit 1
}

try {
    $EncryptedPassword = (Get-Content -Path $CredentialFile -Raw).Trim()

    if ([string]::IsNullOrWhiteSpace($EncryptedPassword)) {
        throw "SMTP credential file is empty."
    }

    $EncryptedBytes = [Convert]::FromBase64String($EncryptedPassword)

    $PasswordBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $EncryptedBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::LocalMachine
    )

    $Password = [System.Text.Encoding]::UTF8.GetString($PasswordBytes)

    if ([string]::IsNullOrWhiteSpace($Password)) {
        throw "Decrypted SMTP password is empty."
    }

    Write-Log "SMTP credential decrypted successfully."

    # Clear intermediate byte arrays.
    $EncryptedBytes = $null
    $PasswordBytes = $null
    $EncryptedPassword = $null
}
catch {
    Write-Log "ERROR decrypting SMTP password: $($_.Exception.Message)"
    exit 1
}

# ==========================================
# SEND EMAIL
# ==========================================

function Send-USBAlert {
    param(
        [string]$DriveLetter,
        [string]$VolumeName
    )

    $ComputerName = $env:COMPUTERNAME

    try {
        $UserName = (
            Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        ).UserName

        if ([string]::IsNullOrWhiteSpace($UserName)) {
            $UserName = "No interactive user"
        }
    }
    catch {
        $UserName = "Unknown"
    }

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Subject = "USB DEVICE DETECTED - $ComputerName"

    $Body = @"
USB SECURITY ALERT

A USB storage device has been connected.

Computer Name : $ComputerName
Logged-in User: $UserName
Drive Letter  : $DriveLetter
Volume Name   : $VolumeName
Time          : $Time

This is an automated alert generated by Taypro local security policy.
"@

    Write-Log "USB DETECTED | Computer=$ComputerName | User=$UserName | Drive=$DriveLetter | Volume=$VolumeName"

    $Smtp = $null
    $Message = $null

    try {
        $SecurePassword = ConvertTo-SecureString `
            $Password `
            -AsPlainText `
            -Force

        $Credential = New-Object `
            System.Management.Automation.PSCredential(
                $AuthUser,
                $SecurePassword
            )

        $Smtp = New-Object System.Net.Mail.SmtpClient(
            $SmtpServer,
            $SmtpPort
        )

        $Smtp.EnableSsl = $true
        $Smtp.Timeout = 15000
        $Smtp.UseDefaultCredentials = $false
        $Smtp.Credentials = $Credential.GetNetworkCredential()

        $Message = New-Object System.Net.Mail.MailMessage

        $Message.From = $From
        $Message.To.Add($To)
        $Message.Subject = $Subject
        $Message.Body = $Body

        $Smtp.Send($Message)

        Write-Log "EMAIL SENT SUCCESSFULLY."
    }
    catch {
        Write-Log "EMAIL FAILED: $($_.Exception.Message)"
    }
    finally {
        if ($Message) {
            $Message.Dispose()
        }

        if ($Smtp) {
            $Smtp.Dispose()
        }

        $SecurePassword = $null
        $Credential = $null
    }
}

# ==========================================
# REGISTER USB INSERTION EVENT
# ==========================================

$query = @"
SELECT * FROM Win32_VolumeChangeEvent
WHERE EventType = 2
"@

try {
    # Remove any stale subscription created by a previous run in this
    # PowerShell process/session.
    Unregister-Event `
        -SourceIdentifier "TayproUSBDetection" `
        -ErrorAction SilentlyContinue

    Register-WmiEvent `
        -Query $query `
        -SourceIdentifier "TayproUSBDetection" `
        -Namespace "root\CIMV2" `
        -ErrorAction Stop | Out-Null

    Write-Log "USB insertion event registered successfully."
}
catch {
    Write-Log "ERROR registering USB event: $($_.Exception.Message)"
    exit 1
}

# ==========================================
# MONITOR CLEANUP
# ==========================================

$Cleanup = {
    try {
        Unregister-Event `
            -SourceIdentifier "TayproUSBDetection" `
            -ErrorAction SilentlyContinue

        Remove-Event `
            -SourceIdentifier "TayproUSBDetection" `
            -ErrorAction SilentlyContinue
    }
    catch {
    }
}

# ==========================================
# START MONITOR
# ==========================================

Write-Log "TAYPRO USB SECURITY MONITOR STARTED"
Write-Log "Waiting for USB storage device insertion..."

# ==========================================
# CONTINUOUS MONITORING
# ==========================================

try {
    while ($true) {

        try {
            $Event = Wait-Event `
                -SourceIdentifier "TayproUSBDetection" `
                -Timeout 30

            if ($null -eq $Event) {
                continue
            }

            try {
                $DriveLetter = $Event.SourceEventArgs.NewEvent.DriveName

                Start-Sleep -Seconds 2

                if (-not [string]::IsNullOrWhiteSpace($DriveLetter)) {

                    $SafeDriveLetter = $DriveLetter.Replace("'", "''")

                    $Volume = Get-CimInstance `
                        Win32_LogicalDisk `
                        -Filter "DeviceID='$SafeDriveLetter'" `
                        -ErrorAction SilentlyContinue

                    if ($Volume) {

                        $VolumeName = [string]$Volume.VolumeName

                        Send-USBAlert `
                            -DriveLetter $DriveLetter `
                            -VolumeName $VolumeName
                    }
                    else {
                        Write-Log "USB event received but logical disk was not available: $DriveLetter"
                    }
                }
            }
            catch {
                Write-Log "USB EVENT ERROR: $($_.Exception.Message)"
            }

            Remove-Event `
                -SourceIdentifier "TayproUSBDetection" `
                -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "MONITOR ERROR: $($_.Exception.Message)"
            Start-Sleep -Seconds 5
        }
    }
}
finally {
    & $Cleanup
    Write-Log "TAYPRO USB SECURITY MONITOR STOPPED"
}
