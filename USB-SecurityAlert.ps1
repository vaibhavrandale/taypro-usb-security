

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
# GET USB STORAGE DEVICE DETAILS
# ==========================================

function Get-USBStorageDeviceDetails {

    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceID
    )

    try {

        # Win32_DiskDrive is used here instead of Win32_PnPEntity.
        # This is the important filter that prevents keyboard, mouse,
        # HID, webcam, audio, HDMI, USB hub, etc. from generating alerts.
        $EscapedId = $DeviceID.Replace("\", "\\").Replace("'", "''")

        $Disk = Get-CimInstance `
            -ClassName Win32_DiskDrive `
            -Filter "DeviceID='$EscapedId'" `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($Disk) {

            $DriveLetters = @()

            try {

                # Disk -> Partition -> Logical Disk
                $Partitions = Get-CimAssociatedInstance `
                    -InputObject $Disk `
                    -ResultClassName Win32_DiskPartition `
                    -ErrorAction SilentlyContinue

                foreach ($Partition in @($Partitions)) {

                    $LogicalDisks = Get-CimAssociatedInstance `
                        -InputObject $Partition `
                        -ResultClassName Win32_LogicalDisk `
                        -ErrorAction SilentlyContinue

                    foreach ($LogicalDisk in @($LogicalDisks)) {

                        if ($LogicalDisk.DeviceID) {
                            $DriveLetters += $LogicalDisk.DeviceID
                        }
                    }
                }
            }
            catch {
                # Drive-letter lookup is optional. Detection must continue.
            }

            $DriveLetterText = "No drive letter"

            if ($DriveLetters.Count -gt 0) {
                $DriveLetterText = (
                    $DriveLetters |
                    Sort-Object -Unique
                ) -join ", "
            }

            $CapacityText = "Unknown"

            if ($Disk.Size) {
                try {
                    $CapacityText = "{0:N2} GB" -f (
                        [double]$Disk.Size / 1GB
                    )
                }
                catch {
                    $CapacityText = "Unknown"
                }
            }

            $DeviceClass = "DiskDrive"

            if ($Disk.PNPDeviceID -like "USBSTOR\*") {
                $DeviceClass = "USBSTOR"
            }

            return [PSCustomObject]@{
                Name          = if ($Disk.Model) {
                    [string]$Disk.Model
                } else {
                    "USB Storage Device"
                }

                Description   = if ($Disk.MediaType) {
                    [string]$Disk.MediaType
                } else {
                    "USB Mass Storage Device"
                }

                Manufacturer  = if ($Disk.Manufacturer) {
                    [string]$Disk.Manufacturer
                } else {
                    "Unknown"
                }

                DeviceID      = if ($Disk.PNPDeviceID) {
                    [string]$Disk.PNPDeviceID
                } else {
                    [string]$DeviceID
                }

                Status        = if ($Disk.Status) {
                    [string]$Disk.Status
                } else {
                    "Unknown"
                }

                Class         = $DeviceClass

                InterfaceType = if ($Disk.InterfaceType) {
                    [string]$Disk.InterfaceType
                } else {
                    "USB"
                }

                Size          = $Disk.Size

                Capacity      = $CapacityText

                DriveLetters = $DriveLetterText
            }
        }
    }
    catch {
        Write-Log "STORAGE DEVICE DETAIL ERROR: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Name           = "USB Storage Device"
        Description    = "USB Mass Storage Device"
        Manufacturer   = "Unknown"
        DeviceID       = $DeviceID
        Status         = "Unknown"
        Class          = "USBSTOR"
        InterfaceType  = "USB"
        Size           = $null
        Capacity       = "Unknown"
        DriveLetters   = "Unknown"
    }
}


# ==========================================
# SEND STORAGE DEVICE EMAIL
# ==========================================

function Send-USBStorageAlert {

    param(
        [Parameter(Mandatory = $true)]
        $Device
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $UserName = Get-LoggedInUser

    $Subject = "USB STORAGE DEVICE DETECTED - $ComputerName"

    $Body = @"
TAYPRO USB SECURITY ALERT
=========================

A USB STORAGE DEVICE has been connected to the computer.

Computer Name : $ComputerName
Logged-in User: $UserName

Storage Device
-------------------------
Device Name   : $($Device.Name)
Description   : $($Device.Description)
Manufacturer  : $($Device.Manufacturer)
Device Class  : $($Device.Class)
Interface     : $($Device.InterfaceType)
Device Status : $($Device.Status)
Capacity      : $($Device.Capacity)
Drive Letter  : $($Device.DriveLetters)

Device ID:
$($Device.DeviceID)

Detection Time: $Time

USB storage blocking remains active.

This is an automated USB storage security alert generated by Taypro.
"@

    Write-Log "USB STORAGE DETECTED | Computer=$ComputerName | User=$UserName | Device=$($Device.Name) | Manufacturer=$($Device.Manufacturer) | Class=$($Device.Class) | PNPDeviceID=$($Device.DeviceID)"

    $smtp = $null
    $msg = $null
    $networkCredential = $null

    try {

        # ==========================================
        # SMTP CREDENTIAL
        # ==========================================

        $securePassword = ConvertTo-SecureString `
            $Password `
            -AsPlainText `
            -Force

        $smtpCredential = New-Object `
            System.Management.Automation.PSCredential(
                $AuthUser,
                $securePassword
            )

        # ==========================================
        # SMTP CLIENT
        # Uses settings.json values
        # ==========================================

        $smtp = New-Object `
            System.Net.Mail.SmtpClient(
                $SmtpServer,
                $SmtpPort
            )

        $smtp.EnableSsl = $true
        $smtp.UseDefaultCredentials = $false

        $networkCredential = $smtpCredential.GetNetworkCredential()

        $smtp.Credentials = $networkCredential

        $smtp.Timeout = 15000

        # ==========================================
        # MESSAGE
        # ==========================================

        $msg = New-Object `
            System.Net.Mail.MailMessage

        $msg.From = $From
        $msg.To.Add($To)
        $msg.Subject = $Subject
        $msg.Body = $Body
        $msg.IsBodyHtml = $false

        # ==========================================
        # SEND
        # ==========================================

        Write-Log "Attempting SMTP send | Server=$SmtpServer | Port=$SmtpPort | User=$AuthUser | StorageDevice=$($Device.Name)"

        $smtp.Send($msg)

        Write-Log "EMAIL SENT SUCCESSFULLY | StorageDevice=$($Device.Name) | To=$To"

        return $true
    }
    catch {

        Write-Log "EMAIL FAILED | StorageDevice=$($Device.Name) | Error=$($_.Exception.ToString())"

        return $false
    }
    finally {

        if ($msg) {
            $msg.Dispose()
        }

        if ($smtp) {
            $smtp.Dispose()
        }

        $networkCredential = $null
        $securePassword = $null
        $smtpCredential = $null
    }
}


# ==========================================
# GET CURRENT USB STORAGE DEVICES
# ==========================================

function Get-CurrentUSBStorageDevices {

    try {

        # IMPORTANT:
        # Do NOT use Win32_PnPEntity with PNPDeviceID -like "USB\*".
        #
        # That detects ALL USB PnP devices:
        #   - Mouse
        #   - Keyboard
        #   - HID
        #   - Webcam
        #   - Audio
        #   - USB Hub
        #   - Composite devices
        #
        # Instead, enumerate physical disk drives and accept only
        # USB storage devices.

        $Disks = Get-CimInstance `
            -ClassName Win32_DiskDrive `
            -ErrorAction Stop |
            Where-Object {

                # Primary storage identification.
                # USBSTOR is Windows' USB mass-storage device class.
                (
                    $_.PNPDeviceID -like "USBSTOR\*"
                ) -or (
                    $_.InterfaceType -eq "USB" -and
                    $_.PNPDeviceID -like "USB\*"
                )
            }

        if ($null -eq $Disks) {
            return @()
        }

        return @(
            $Disks |
            ForEach-Object {

                [PSCustomObject]@{
                    DeviceID    = [string]$_.DeviceID
                    PNPDeviceID = [string]$_.PNPDeviceID
                    Model       = [string]$_.Model
                }
            }
        )
    }
    catch {

        Write-Log "USB STORAGE ENUMERATION ERROR: $($_.Exception.Message)"

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
Write-Log "Detection Method: USB Storage / Win32_DiskDrive"
Write-Log "USB storage blocking remains enabled."
Write-Log "Keyboard, mouse, HID, HDMI, webcam, audio and other non-storage USB devices are ignored."
Write-Log "=========================================="


# ==========================================
# INITIAL STORAGE DEVICE SNAPSHOT
# ==========================================

$KnownStorageDevices = @{}

try {

    $InitialDevices = Get-CurrentUSBStorageDevices

    foreach ($StorageDevice in $InitialDevices) {

        $DeviceID = $StorageDevice.DeviceID

        if (-not [string]::IsNullOrWhiteSpace($DeviceID)) {

            $KnownStorageDevices[$DeviceID] = $true
        }
    }

    Write-Log "INITIAL USB STORAGE DEVICES: $($KnownStorageDevices.Count)"
}
catch {

    Write-Log "ERROR creating initial USB storage device snapshot: $($_.Exception.Message)"
}


Write-Log "USB STORAGE monitoring loop is active."


# ==========================================
# MAIN STORAGE MONITOR LOOP
# ==========================================

while ($true) {

    try {

        $CurrentDevices = Get-CurrentUSBStorageDevices

        $CurrentSet = @{}

        foreach ($StorageDevice in $CurrentDevices) {

            $DeviceID = $StorageDevice.DeviceID

            if ([string]::IsNullOrWhiteSpace($DeviceID)) {
                continue
            }

            $CurrentSet[$DeviceID] = $true


            # ==========================================
            # NEW USB STORAGE DEVICE
            # ==========================================

            if (-not $KnownStorageDevices.ContainsKey($DeviceID)) {

                # Give Windows a short amount of time to finish
                # creating the disk/partition/drive associations.
                Start-Sleep -Milliseconds 1000

                $Device = Get-USBStorageDeviceDetails `
                    -DeviceID $DeviceID

                Write-Log "NEW USB STORAGE DEVICE | Name=$($Device.Name) | Manufacturer=$($Device.Manufacturer) | Class=$($Device.Class) | Drive=$($Device.DriveLetters) | DeviceID=$DeviceID"

                Send-USBStorageAlert `
                    -Device $Device |
                    Out-Null
            }
        }


        # ==========================================
        # DETECT STORAGE DEVICE REMOVAL
        # ==========================================

        foreach ($OldDeviceID in @($KnownStorageDevices.Keys)) {

            if (-not $CurrentSet.ContainsKey($OldDeviceID)) {

                Write-Log "USB STORAGE DEVICE REMOVED | DeviceID=$OldDeviceID"
            }
        }


        # ==========================================
        # UPDATE SNAPSHOT
        # ==========================================

        $KnownStorageDevices = $CurrentSet

    }
    catch {

        Write-Log "MONITOR LOOP ERROR: $($_.Exception.Message)"
    }


    # Poll every 2 seconds.
    Start-Sleep -Seconds 2
}

