#Requires -Version 5.1

# ==========================================
# TAYPRO USB SECURITY MONITOR
# USB STORAGE INSERTION ALERT
# ==========================================

$BasePath      = "C:\ProgramData\Taypro\USBSecurity"
$ConfigFile    = Join-Path $BasePath "settings.json"
$CredentialFile = Join-Path $BasePath "smtp-secret.dat"
$LogFile       = Join-Path $BasePath "USBSecurity.log"

# Polling interval in seconds
$PollIntervalSeconds = 2

# Number of attempts to wait for the USB volume to become ready
$VolumeReadyAttempts = 10

# Delay between volume-ready attempts
$VolumeReadyDelaySeconds = 1

# ==========================================
# CREATE BASE DIRECTORY
# ==========================================

if (-not (Test-Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
}

# ==========================================
# LOG FUNCTION
# ==========================================

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        Add-Content `
            -Path $LogFile `
            -Value "[$Time] $Message" `
            -ErrorAction Stop
    }
    catch {
        # Do not terminate the USB monitor if logging fails.
    }
}

# ==========================================
# LOAD CONFIGURATION
# ==========================================

if (-not (Test-Path $ConfigFile)) {
    Write-Log "ERROR: settings.json not found: $ConfigFile"
    exit 1
}

try {
    $Config = Get-Content `
        -Path $ConfigFile `
        -Raw `
        -ErrorAction Stop |
        ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($Config.SmtpServer)) {
        throw "SmtpServer is missing."
    }

    if ([string]::IsNullOrWhiteSpace([string]$Config.SmtpPort)) {
        throw "SmtpPort is missing."
    }

    if ([string]::IsNullOrWhiteSpace($Config.From)) {
        throw "From address is missing."
    }

    if ([string]::IsNullOrWhiteSpace($Config.To)) {
        throw "To address is missing."
    }

    if ([string]::IsNullOrWhiteSpace($Config.AuthUser)) {
        throw "AuthUser is missing."
    }

    $SmtpServer = [string]$Config.SmtpServer
    $SmtpPort   = [int]$Config.SmtpPort
    $From       = [string]$Config.From
    $To         = [string]$Config.To
    $AuthUser   = [string]$Config.AuthUser
}
catch {
    Write-Log "ERROR loading configuration: $($_.Exception.Message)"
    exit 1
}

# ==========================================
# LOAD ENCRYPTED SMTP PASSWORD
# ==========================================

if (-not (Test-Path $CredentialFile)) {
    Write-Log "ERROR: SMTP credential not found: $CredentialFile"
    exit 1
}

try {
    Add-Type -AssemblyName System.Security -ErrorAction Stop

    $EncryptedPassword = (
        Get-Content `
            -Path $CredentialFile `
            -Raw `
            -ErrorAction Stop
    ).Trim()

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

    # Clear sensitive intermediate data
    $PasswordBytes = $null
    $EncryptedBytes = $null
    $EncryptedPassword = $null
}
catch {
    Write-Log "ERROR decrypting SMTP password: $($_.Exception.Message)"
    exit 1
}

# ==========================================
# GET LOGGED-IN USER
# ==========================================

function Get-LoggedInUser {

    try {
        $ComputerSystem = Get-CimInstance `
            -ClassName Win32_ComputerSystem `
            -ErrorAction Stop

        if (-not [string]::IsNullOrWhiteSpace($ComputerSystem.UserName)) {
            return $ComputerSystem.UserName
        }

        return "No interactive user detected"
    }
    catch {
        return "Unknown"
    }
}

# ==========================================
# GET USB STORAGE DRIVES
# ==========================================

function Get-USBDrives {

    try {

        $Drives = Get-CimInstance `
            -ClassName Win32_LogicalDisk `
            -Filter "DriveType = 2" `
            -ErrorAction Stop

        if ($null -eq $Drives) {
            return @()
        }

        return @($Drives)
    }
    catch {

        Write-Log "USB ENUMERATION ERROR: $($_.Exception.Message)"

        return @()
    }
}

# ==========================================
# SEND USB ALERT EMAIL
# ==========================================

function Send-USBAlert {

    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter,

        [string]$VolumeName,

        [string]$FileSystem,

        [string]$VolumeSerialNumber,

        [string]$SizeGB
    )

    $ComputerName = $env:COMPUTERNAME
    $UserName = Get-LoggedInUser
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ([string]::IsNullOrWhiteSpace($VolumeName)) {
        $VolumeName = "No label"
    }

    if ([string]::IsNullOrWhiteSpace($FileSystem)) {
        $FileSystem = "Unknown"
    }

    if ([string]::IsNullOrWhiteSpace($VolumeSerialNumber)) {
        $VolumeSerialNumber = "Unknown"
    }

    if ([string]::IsNullOrWhiteSpace($SizeGB)) {
        $SizeGB = "Unknown"
    }

    $Subject = "USB DEVICE DETECTED - $ComputerName"

    $Body = @"
USB SECURITY ALERT
==================

A USB storage device has been connected to the computer.

Computer Name      : $ComputerName
Logged-in User     : $UserName
Drive Letter       : $DriveLetter
Volume Name        : $VolumeName
File System        : $FileSystem
Volume Serial      : $VolumeSerialNumber
Drive Size         : $SizeGB GB
Detection Time     : $Time

This is an automated USB security alert generated by Taypro.
"@

    Write-Log "USB DETECTED | Computer=$ComputerName | User=$UserName | Drive=$DriveLetter | Volume=$VolumeName"

    $Smtp = $null
    $Message = $null

    try {

        $SecurePassword = ConvertTo-SecureString `
            -String $Password `
            -AsPlainText `
            -Force

        $Credential = New-Object `
            System.Management.Automation.PSCredential(
                $AuthUser,
                $SecurePassword
            )

        $Smtp = New-Object `
            System.Net.Mail.SmtpClient(
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
        $Message.IsBodyHtml = $false

        $Smtp.Send($Message)

        Write-Log "EMAIL SENT SUCCESSFULLY | Drive=$DriveLetter | To=$To"

        return $true
    }
    catch {

        Write-Log "EMAIL FAILED | Drive=$DriveLetter | Error=$($_.Exception.Message)"

        return $false
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
# WAIT FOR USB VOLUME TO BECOME READY
# ==========================================

function Get-ReadyUSBDrive {

    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )

    for ($Attempt = 1; $Attempt -le $VolumeReadyAttempts; $Attempt++) {

        try {

            $Drive = Get-CimInstance `
                -ClassName Win32_LogicalDisk `
                -Filter "DeviceID='$DriveLetter'" `
                -ErrorAction Stop

            if ($Drive) {
                return $Drive
            }
        }
        catch {
            # USB may still be initializing.
        }

        Start-Sleep -Seconds $VolumeReadyDelaySeconds
    }

    return $null
}

# ==========================================
# START MONITOR
# ==========================================

Write-Log "=========================================="
Write-Log "TAYPRO USB SECURITY MONITOR STARTED"
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "Running As: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "Detection Method: USB storage polling"
Write-Log "Polling Interval: $PollIntervalSeconds seconds"
Write-Log "=========================================="

# ==========================================
# INITIAL USB STATE
# ==========================================

$KnownDrives = @{}

try {

    $InitialDrives = Get-USBDrives

    foreach ($Drive in $InitialDrives) {

        if ($Drive.DeviceID) {
            $KnownDrives[$Drive.DeviceID] = $true

            Write-Log "INITIAL USB DRIVE | Drive=$($Drive.DeviceID) | Volume=$($Drive.VolumeName)"
        }
    }

}
catch {

    Write-Log "INITIAL USB ENUMERATION ERROR: $($_.Exception.Message)"
}

Write-Log "USB monitoring loop is active."

# ==========================================
# CONTINUOUS USB MONITOR
# ==========================================

while ($true) {

    try {

        $CurrentDrives = Get-USBDrives

        $CurrentDriveMap = @{}

        foreach ($Drive in $CurrentDrives) {

            $DriveLetter = [string]$Drive.DeviceID

            if ([string]::IsNullOrWhiteSpace($DriveLetter)) {
                continue
            }

            $CurrentDriveMap[$DriveLetter] = $true

            # ==========================================
            # NEW USB DRIVE DETECTED
            # ==========================================

            if (-not $KnownDrives.ContainsKey($DriveLetter)) {

                Write-Log "NEW USB DRIVE FOUND | Drive=$DriveLetter"

                # Give Windows time to finish mounting the device.
                $ReadyDrive = Get-ReadyUSBDrive `
                    -DriveLetter $DriveLetter

                if ($ReadyDrive) {

                    $VolumeName = [string]$ReadyDrive.VolumeName
                    $FileSystem = [string]$ReadyDrive.FileSystem
                    $Serial = [string]$ReadyDrive.VolumeSerialNumber

                    $SizeGB = "Unknown"

                    if ($ReadyDrive.Size) {
                        $SizeGB = [math]::Round(
                            ($ReadyDrive.Size / 1GB),
                            2
                        )
                    }

                    Write-Log "USB READY | Drive=$DriveLetter | Volume=$VolumeName | FileSystem=$FileSystem | SizeGB=$SizeGB"

                    Send-USBAlert `
                        -DriveLetter $DriveLetter `
                        -VolumeName $VolumeName `
                        -FileSystem $FileSystem `
                        -VolumeSerialNumber $Serial `
                        -SizeGB $SizeGB | Out-Null
                }
                else {

                    Write-Log "USB DETECTED BUT VOLUME NOT READY | Drive=$DriveLetter"
                }
            }
        }

        # ==========================================
        # REMOVE DISCONNECTED DRIVES
        # ==========================================

        $DisconnectedDrives = @(
            $KnownDrives.Keys |
            Where-Object {
                -not $CurrentDriveMap.ContainsKey($_)
            }
        )

        foreach ($DisconnectedDrive in $DisconnectedDrives) {

            Write-Log "USB REMOVED | Drive=$DisconnectedDrive"

            $KnownDrives.Remove($DisconnectedDrive)
        }

        # ==========================================
        # UPDATE STATE
        # ==========================================

        foreach ($DriveLetter in $CurrentDriveMap.Keys) {
            $KnownDrives[$DriveLetter] = $true
        }

    }
    catch {

        Write-Log "MONITOR ERROR: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $PollIntervalSeconds
}
