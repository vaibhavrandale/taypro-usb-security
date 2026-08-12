

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
        # SAME CONFIGURATION AS SUCCESSFUL TEST
        # ==========================================

        $smtp = New-Object `
            System.Net.Mail.SmtpClient(
                "smtp.hostinger.com",
                587
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

        Write-Log "Attempting SMTP send | Server=smtp.hostinger.com | Port=587 | User=$AuthUser"

        $smtp.Send($msg)

        Write-Log "EMAIL SENT SUCCESSFULLY | Device=$($Device.Name) | To=$To"

        return $true

    }
    catch {

        Write-Log "EMAIL FAILED | Device=$($Device.Name) | Error=$($_.Exception.ToString())"

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







