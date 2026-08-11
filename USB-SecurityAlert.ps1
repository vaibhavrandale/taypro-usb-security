# #Requires -Version 5.1

# # ==========================================
# # TAYPRO USB SECURITY MONITOR
# # USB STORAGE INSERTION ALERT
# # ==========================================

# $BasePath      = "C:\ProgramData\Taypro\USBSecurity"
# $ConfigFile    = Join-Path $BasePath "settings.json"
# $CredentialFile = Join-Path $BasePath "smtp-secret.dat"
# $LogFile       = Join-Path $BasePath "USBSecurity.log"

# # Polling interval in seconds
# $PollIntervalSeconds = 2

# # Number of attempts to wait for the USB volume to become ready
# $VolumeReadyAttempts = 10

# # Delay between volume-ready attempts
# $VolumeReadyDelaySeconds = 1

# # ==========================================
# # CREATE BASE DIRECTORY
# # ==========================================

# if (-not (Test-Path $BasePath)) {
#     New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
# }

# # ==========================================
# # LOG FUNCTION
# # ==========================================

# function Write-Log {
#     param(
#         [Parameter(Mandatory = $true)]
#         [string]$Message
#     )

#     try {
#         $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

#         Add-Content `
#             -Path $LogFile `
#             -Value "[$Time] $Message" `
#             -ErrorAction Stop
#     }
#     catch {
#         # Do not terminate the USB monitor if logging fails.
#     }
# }

# # ==========================================
# # LOAD CONFIGURATION
# # ==========================================

# if (-not (Test-Path $ConfigFile)) {
#     Write-Log "ERROR: settings.json not found: $ConfigFile"
#     exit 1
# }

# try {
#     $Config = Get-Content `
#         -Path $ConfigFile `
#         -Raw `
#         -ErrorAction Stop |
#         ConvertFrom-Json

#     if ([string]::IsNullOrWhiteSpace($Config.SmtpServer)) {
#         throw "SmtpServer is missing."
#     }

#     if ([string]::IsNullOrWhiteSpace([string]$Config.SmtpPort)) {
#         throw "SmtpPort is missing."
#     }

#     if ([string]::IsNullOrWhiteSpace($Config.From)) {
#         throw "From address is missing."
#     }

#     if ([string]::IsNullOrWhiteSpace($Config.To)) {
#         throw "To address is missing."
#     }

#     if ([string]::IsNullOrWhiteSpace($Config.AuthUser)) {
#         throw "AuthUser is missing."
#     }

#     $SmtpServer = [string]$Config.SmtpServer
#     $SmtpPort   = [int]$Config.SmtpPort
#     $From       = [string]$Config.From
#     $To         = [string]$Config.To
#     $AuthUser   = [string]$Config.AuthUser
# }
# catch {
#     Write-Log "ERROR loading configuration: $($_.Exception.Message)"
#     exit 1
# }

# # ==========================================
# # LOAD ENCRYPTED SMTP PASSWORD
# # ==========================================

# if (-not (Test-Path $CredentialFile)) {
#     Write-Log "ERROR: SMTP credential not found: $CredentialFile"
#     exit 1
# }

# try {
#     Add-Type -AssemblyName System.Security -ErrorAction Stop

#     $EncryptedPassword = (
#         Get-Content `
#             -Path $CredentialFile `
#             -Raw `
#             -ErrorAction Stop
#     ).Trim()

#     if ([string]::IsNullOrWhiteSpace($EncryptedPassword)) {
#         throw "SMTP credential file is empty."
#     }

#     $EncryptedBytes = [Convert]::FromBase64String($EncryptedPassword)

#     $PasswordBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
#         $EncryptedBytes,
#         $null,
#         [System.Security.Cryptography.DataProtectionScope]::LocalMachine
#     )

#     $Password = [System.Text.Encoding]::UTF8.GetString($PasswordBytes)

#     if ([string]::IsNullOrWhiteSpace($Password)) {
#         throw "Decrypted SMTP password is empty."
#     }

#     # Clear sensitive intermediate data
#     $PasswordBytes = $null
#     $EncryptedBytes = $null
#     $EncryptedPassword = $null
# }
# catch {
#     Write-Log "ERROR decrypting SMTP password: $($_.Exception.Message)"
#     exit 1
# }

# # ==========================================
# # GET LOGGED-IN USER
# # ==========================================

# function Get-LoggedInUser {

#     try {
#         $ComputerSystem = Get-CimInstance `
#             -ClassName Win32_ComputerSystem `
#             -ErrorAction Stop

#         if (-not [string]::IsNullOrWhiteSpace($ComputerSystem.UserName)) {
#             return $ComputerSystem.UserName
#         }

#         return "No interactive user detected"
#     }
#     catch {
#         return "Unknown"
#     }
# }

# # ==========================================
# # GET USB STORAGE DRIVES
# # ==========================================

# function Get-USBDrives {

#     try {

#         $Drives = Get-CimInstance `
#             -ClassName Win32_LogicalDisk `
#             -Filter "DriveType = 2" `
#             -ErrorAction Stop

#         if ($null -eq $Drives) {
#             return @()
#         }

#         return @($Drives)
#     }
#     catch {

#         Write-Log "USB ENUMERATION ERROR: $($_.Exception.Message)"

#         return @()
#     }
# }

# # ==========================================
# # SEND USB ALERT EMAIL
# # ==========================================

# function Send-USBAlert {

#     param(
#         [Parameter(Mandatory = $true)]
#         [string]$DriveLetter,

#         [string]$VolumeName,

#         [string]$FileSystem,

#         [string]$VolumeSerialNumber,

#         [string]$SizeGB
#     )

#     $ComputerName = $env:COMPUTERNAME
#     $UserName = Get-LoggedInUser
#     $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

#     if ([string]::IsNullOrWhiteSpace($VolumeName)) {
#         $VolumeName = "No label"
#     }

#     if ([string]::IsNullOrWhiteSpace($FileSystem)) {
#         $FileSystem = "Unknown"
#     }

#     if ([string]::IsNullOrWhiteSpace($VolumeSerialNumber)) {
#         $VolumeSerialNumber = "Unknown"
#     }

#     if ([string]::IsNullOrWhiteSpace($SizeGB)) {
#         $SizeGB = "Unknown"
#     }

#     $Subject = "USB DEVICE DETECTED - $ComputerName"

#     $Body = @"
# USB SECURITY ALERT
# ==================

# A USB storage device has been connected to the computer.

# Computer Name      : $ComputerName
# Logged-in User     : $UserName
# Drive Letter       : $DriveLetter
# Volume Name        : $VolumeName
# File System        : $FileSystem
# Volume Serial      : $VolumeSerialNumber
# Drive Size         : $SizeGB GB
# Detection Time     : $Time

# This is an automated USB security alert generated by Taypro.
# "@

#     Write-Log "USB DETECTED | Computer=$ComputerName | User=$UserName | Drive=$DriveLetter | Volume=$VolumeName"

#     $Smtp = $null
#     $Message = $null

#     try {

#         $SecurePassword = ConvertTo-SecureString `
#             -String $Password `
#             -AsPlainText `
#             -Force

#         $Credential = New-Object `
#             System.Management.Automation.PSCredential(
#                 $AuthUser,
#                 $SecurePassword
#             )

#         $Smtp = New-Object `
#             System.Net.Mail.SmtpClient(
#                 $SmtpServer,
#                 $SmtpPort
#             )

#         $Smtp.EnableSsl = $true
#         $Smtp.Timeout = 15000
#         $Smtp.UseDefaultCredentials = $false
#         $Smtp.Credentials = $Credential.GetNetworkCredential()

#         $Message = New-Object System.Net.Mail.MailMessage

#         $Message.From = $From
#         $Message.To.Add($To)
#         $Message.Subject = $Subject
#         $Message.Body = $Body
#         $Message.IsBodyHtml = $false

#         $Smtp.Send($Message)

#         Write-Log "EMAIL SENT SUCCESSFULLY | Drive=$DriveLetter | To=$To"

#         return $true
#     }
#     catch {

#         Write-Log "EMAIL FAILED | Drive=$DriveLetter | Error=$($_.Exception.Message)"

#         return $false
#     }
#     finally {

#         if ($Message) {
#             $Message.Dispose()
#         }

#         if ($Smtp) {
#             $Smtp.Dispose()
#         }

#         $SecurePassword = $null
#         $Credential = $null
#     }
# }

# # ==========================================
# # WAIT FOR USB VOLUME TO BECOME READY
# # ==========================================

# function Get-ReadyUSBDrive {

#     param(
#         [Parameter(Mandatory = $true)]
#         [string]$DriveLetter
#     )

#     for ($Attempt = 1; $Attempt -le $VolumeReadyAttempts; $Attempt++) {

#         try {

#             $Drive = Get-CimInstance `
#                 -ClassName Win32_LogicalDisk `
#                 -Filter "DeviceID='$DriveLetter'" `
#                 -ErrorAction Stop

#             if ($Drive) {
#                 return $Drive
#             }
#         }
#         catch {
#             # USB may still be initializing.
#         }

#         Start-Sleep -Seconds $VolumeReadyDelaySeconds
#     }

#     return $null
# }

# # ==========================================
# # START MONITOR
# # ==========================================

# Write-Log "=========================================="
# Write-Log "TAYPRO USB SECURITY MONITOR STARTED"
# Write-Log "Computer: $env:COMPUTERNAME"
# Write-Log "Running As: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
# Write-Log "Detection Method: USB storage polling"
# Write-Log "Polling Interval: $PollIntervalSeconds seconds"
# Write-Log "=========================================="

# # ==========================================
# # INITIAL USB STATE
# # ==========================================

# $KnownDrives = @{}

# try {

#     $InitialDrives = Get-USBDrives

#     foreach ($Drive in $InitialDrives) {

#         if ($Drive.DeviceID) {
#             $KnownDrives[$Drive.DeviceID] = $true

#             Write-Log "INITIAL USB DRIVE | Drive=$($Drive.DeviceID) | Volume=$($Drive.VolumeName)"
#         }
#     }

# }
# catch {

#     Write-Log "INITIAL USB ENUMERATION ERROR: $($_.Exception.Message)"
# }

# Write-Log "USB monitoring loop is active."

# # ==========================================
# # CONTINUOUS USB MONITOR
# # ==========================================

# while ($true) {

#     try {

#         $CurrentDrives = Get-USBDrives

#         $CurrentDriveMap = @{}

#         foreach ($Drive in $CurrentDrives) {

#             $DriveLetter = [string]$Drive.DeviceID

#             if ([string]::IsNullOrWhiteSpace($DriveLetter)) {
#                 continue
#             }

#             $CurrentDriveMap[$DriveLetter] = $true

#             # ==========================================
#             # NEW USB DRIVE DETECTED
#             # ==========================================

#             if (-not $KnownDrives.ContainsKey($DriveLetter)) {

#                 Write-Log "NEW USB DRIVE FOUND | Drive=$DriveLetter"

#                 # Give Windows time to finish mounting the device.
#                 $ReadyDrive = Get-ReadyUSBDrive `
#                     -DriveLetter $DriveLetter

#                 if ($ReadyDrive) {

#                     $VolumeName = [string]$ReadyDrive.VolumeName
#                     $FileSystem = [string]$ReadyDrive.FileSystem
#                     $Serial = [string]$ReadyDrive.VolumeSerialNumber

#                     $SizeGB = "Unknown"

#                     if ($ReadyDrive.Size) {
#                         $SizeGB = [math]::Round(
#                             ($ReadyDrive.Size / 1GB),
#                             2
#                         )
#                     }

#                     Write-Log "USB READY | Drive=$DriveLetter | Volume=$VolumeName | FileSystem=$FileSystem | SizeGB=$SizeGB"

#                     Send-USBAlert `
#                         -DriveLetter $DriveLetter `
#                         -VolumeName $VolumeName `
#                         -FileSystem $FileSystem `
#                         -VolumeSerialNumber $Serial `
#                         -SizeGB $SizeGB | Out-Null
#                 }
#                 else {

#                     Write-Log "USB DETECTED BUT VOLUME NOT READY | Drive=$DriveLetter"
#                 }
#             }
#         }

#         # ==========================================
#         # REMOVE DISCONNECTED DRIVES
#         # ==========================================

#         $DisconnectedDrives = @(
#             $KnownDrives.Keys |
#             Where-Object {
#                 -not $CurrentDriveMap.ContainsKey($_)
#             }
#         )

#         foreach ($DisconnectedDrive in $DisconnectedDrives) {

#             Write-Log "USB REMOVED | Drive=$DisconnectedDrive"

#             $KnownDrives.Remove($DisconnectedDrive)
#         }

#         # ==========================================
#         # UPDATE STATE
#         # ==========================================

#         foreach ($DriveLetter in $CurrentDriveMap.Keys) {
#             $KnownDrives[$DriveLetter] = $true
#         }

#     }
#     catch {

#         Write-Log "MONITOR ERROR: $($_.Exception.Message)"
#     }

#     Start-Sleep -Seconds $PollIntervalSeconds
# }



#Requires -Version 5.1

# ==========================================
# TAYPRO USB SECURITY MONITOR
# USB / PnP INSERTION ALERT
# ==========================================

$ErrorActionPreference = "Stop"

$BasePath       = "C:\ProgramData\Taypro\USBSecurity"
$ConfigFile     = Join-Path $BasePath "settings.json"
$CredentialFile = Join-Path $BasePath "smtp-secret.dat"
$LogFile        = Join-Path $BasePath "USBSecurity.log"

# ==========================================
# CREATE DIRECTORY
# ==========================================

if (-not (Test-Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
}

# ==========================================
# LOGGING
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
        # Never terminate monitor because logging failed.
    }
}

# ==========================================
# LOAD CONFIG
# ==========================================

if (-not (Test-Path $ConfigFile)) {
    Write-Log "ERROR: settings.json not found."
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
# NATIVE WINDOWS DPAPI
# ==========================================

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

    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CryptUnprotectData(
        ref DATA_BLOB pDataIn,
        IntPtr ppszDataDescr,
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
            Marshal.Copy(plainBytes, 0, input.pbData, plainBytes.Length);

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

    public static byte[] Unprotect(byte[] encryptedBytes)
    {
        DATA_BLOB input = new DATA_BLOB();
        DATA_BLOB output;

        input.cbData = encryptedBytes.Length;
        input.pbData = Marshal.AllocHGlobal(encryptedBytes.Length);

        try
        {
            Marshal.Copy(
                encryptedBytes,
                0,
                input.pbData,
                encryptedBytes.Length
            );

            bool result = CryptUnprotectData(
                ref input,
                IntPtr.Zero,
                IntPtr.Zero,
                IntPtr.Zero,
                IntPtr.Zero,
                0,
                out output
            );

            if (!result)
            {
                throw new System.ComponentModel.Win32Exception(
                    Marshal.GetLastWin32Error()
                );
            }

            byte[] plain = new byte[output.cbData];

            Marshal.Copy(
                output.pbData,
                plain,
                0,
                output.cbData
            );

            LocalFree(output.pbData);

            return plain;
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

# ==========================================
# LOAD SMTP PASSWORD
# ==========================================

if (-not (Test-Path $CredentialFile)) {

    Write-Log "ERROR: smtp-secret.dat not found."
    exit 1
}

try {

    $EncryptedBase64 = (
        Get-Content `
            -Path $CredentialFile `
            -Raw `
            -ErrorAction Stop
    ).Trim()

    if ([string]::IsNullOrWhiteSpace($EncryptedBase64)) {
        throw "Encrypted SMTP credential is empty."
    }

    $EncryptedBytes = [Convert]::FromBase64String(
        $EncryptedBase64
    )

    $PasswordBytes = [TayproNativeDPAPI]::Unprotect(
        $EncryptedBytes
    )

    $Password = [System.Text.Encoding]::UTF8.GetString(
        $PasswordBytes
    )

    if ([string]::IsNullOrWhiteSpace($Password)) {
        throw "SMTP password decrypted to an empty value."
    }

    Write-Log "SMTP credential decrypted successfully using native Windows DPAPI."

}
catch {

    Write-Log "ERROR decrypting SMTP credential: $($_.Exception.Message)"
    exit 1
}

# ==========================================
# GET COMPUTER NAME
# ==========================================

$ComputerName = $env:COMPUTERNAME

# ==========================================
# GET LOGGED-IN USER
# ==========================================

function Get-LoggedInUser {

    try {

        $ComputerSystem = Get-CimInstance `
            -ClassName Win32_ComputerSystem `
            -ErrorAction Stop

        if (-not [string]::IsNullOrWhiteSpace(
            $ComputerSystem.UserName
        )) {
            return $ComputerSystem.UserName
        }

        return "No interactive user detected"

    }
    catch {

        return "Unknown"
    }
}

# ==========================================
# GET USB DEVICE DETAILS
# ==========================================

function Get-USBDeviceDetails {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PNPDeviceID
    )

    try {

        $EscapedId = $PNPDeviceID.Replace("\", "\\").Replace("'", "''")

        $Device = Get-CimInstance `
            -ClassName Win32_PnPEntity `
            -Filter "PNPDeviceID='$EscapedId'" `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($Device) {

            return [PSCustomObject]@{
                Name        = if ($Device.Name) { $Device.Name } else { "Unknown" }
                Description = if ($Device.Description) { $Device.Description } else { "Unknown" }
                Manufacturer = if ($Device.Manufacturer) { $Device.Manufacturer } else { "Unknown" }
                DeviceID    = if ($Device.PNPDeviceID) { $Device.PNPDeviceID } else { $PNPDeviceID }
                Status      = if ($Device.Status) { $Device.Status } else { "Unknown" }
                Class       = if ($Device.PNPClass) { $Device.PNPClass } else { "Unknown" }
            }
        }

    }
    catch {
    }

    return [PSCustomObject]@{
        Name         = "USB Device"
        Description  = "USB device"
        Manufacturer = "Unknown"
        DeviceID     = $PNPDeviceID
        Status       = "Unknown"
        Class        = "Unknown"
    }
}

# ==========================================
# SEND EMAIL
# ==========================================

function Send-USBAlert {

    param(
        [Parameter(Mandatory = $true)]
        $Device
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $UserName = Get-LoggedInUser

    $Subject = "USB DEVICE DETECTED - $ComputerName"

    $Body = @"
TAYPRO USB SECURITY ALERT
=========================

A USB device has been connected to the computer.

Computer Name : $ComputerName
Logged-in User: $UserName

Device Name   : $($Device.Name)
Description   : $($Device.Description)
Manufacturer  : $($Device.Manufacturer)
Device Class  : $($Device.Class)
Device Status : $($Device.Status)

Device ID:
$($Device.DeviceID)

Detection Time: $Time

USB storage blocking remains active.

This is an automated USB security alert generated by Taypro.
"@

    Write-Log "USB DETECTED | Computer=$ComputerName | User=$UserName | Device=$($Device.Name) | PNPDeviceID=$($Device.DeviceID)"

    $Smtp = $null
    $Message = $null
    $SecurePassword = $null
    $Credential = $null

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

        $Message = New-Object `
            System.Net.Mail.MailMessage

        $Message.From = $From
        $Message.To.Add($To)
        $Message.Subject = $Subject
        $Message.Body = $Body
        $Message.IsBodyHtml = $false

        $Smtp.Send($Message)

        Write-Log "EMAIL SENT SUCCESSFULLY | Device=$($Device.Name) | To=$To"

        return $true

    }
    catch {

        Write-Log "EMAIL FAILED | Device=$($Device.Name) | Error=$($_.Exception.Message)"

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
# GET INITIAL USB DEVICES
# ==========================================

function Get-CurrentUSBDevices {

    try {

        $Devices = Get-CimInstance `
            -ClassName Win32_PnPEntity `
            -ErrorAction Stop |
            Where-Object {
                $_.PNPDeviceID -like "USB\*"
            }

        if ($null -eq $Devices) {
            return @()
        }

        return @(
            $Devices |
            ForEach-Object {
                $_.PNPDeviceID
            }
        )
    }
    catch {

        Write-Log "USB ENUMERATION ERROR: $($_.Exception.Message)"
        return @()
    }
}

# ==========================================
# STARTUP LOG
# ==========================================

Write-Log "=========================================="
Write-Log "TAYPRO USB SECURITY MONITOR STARTED"
Write-Log "Computer: $ComputerName"
Write-Log "Running As: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "Detection Method: USB/PnP device monitoring"
Write-Log "USB storage blocking remains enabled."
Write-Log "=========================================="

# ==========================================
# INITIAL DEVICE SNAPSHOT
# ==========================================

$KnownDevices = @{}

try {

    $InitialDevices = Get-CurrentUSBDevices

    foreach ($DeviceId in $InitialDevices) {

        if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
            $KnownDevices[$DeviceId] = $true
        }
    }

    Write-Log "INITIAL USB DEVICES: $($KnownDevices.Count)"

}
catch {

    Write-Log "ERROR creating initial USB device snapshot: $($_.Exception.Message)"
}

Write-Log "USB monitoring loop is active."

# ==========================================
# MAIN MONITOR LOOP
# ==========================================

while ($true) {

    try {

        $CurrentDevices = Get-CurrentUSBDevices

        $CurrentSet = @{}

        foreach ($DeviceId in $CurrentDevices) {

            if ([string]::IsNullOrWhiteSpace($DeviceId)) {
                continue
            }

            $CurrentSet[$DeviceId] = $true

            # New USB device
            if (-not $KnownDevices.ContainsKey($DeviceId)) {

                Start-Sleep -Milliseconds 500

                $Device = Get-USBDeviceDetails `
                    -PNPDeviceID $DeviceId

                Write-Log "NEW USB DEVICE | Name=$($Device.Name) | Manufacturer=$($Device.Manufacturer) | Class=$($Device.Class) | DeviceID=$DeviceId"

                Send-USBAlert `
                    -Device $Device | Out-Null
            }
        }

        # Detect removals
        foreach ($OldDeviceId in @($KnownDevices.Keys)) {

            if (-not $CurrentSet.ContainsKey($OldDeviceId)) {

                Write-Log "USB DEVICE REMOVED | DeviceID=$OldDeviceId"
            }
        }

        $KnownDevices = $CurrentSet

    }
    catch {

        Write-Log "MONITOR LOOP ERROR: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 2
}
