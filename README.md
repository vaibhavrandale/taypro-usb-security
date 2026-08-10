Yes. Here is the complete end-to-end command sequence for installing, verifying, testing USB detection, testing email, and testing after reboot.

1. On the new laptop — open PowerShell as Administrator

First verify PowerShell:

$PSVersionTable.PSVersion

Also verify DPAPI before installation:

Add-Type -AssemblyName System.Security

Then:

[System.Security.Cryptography.ProtectedData]

If it returns the type without an error, continue.

2. Create the temporary folder
New-Item -ItemType Directory -Path C:\Temp -Force
cd C:\Temp
3. Download and install from GitHub

Use your repository:

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://github.com/vaibhavrandale/taypro-usb-security/archive/refs/heads/main.zip' -OutFile $env:TEMP\taypro.zip; Remove-Item $env:TEMP\taypro -Recurse -Force -ErrorAction SilentlyContinue; Expand-Archive $env:TEMP\taypro.zip $env:TEMP\taypro -Force; & $env:TEMP\taypro\taypro-usb-security-main\Install.ps1"

The installer should ask:

Enter the Hostinger SMTP password

Enter the SMTP mailbox password.

You should eventually see:

DPAPI loaded successfully.
SMTP credential encrypted successfully.
Scheduled task created successfully.
Starting USB Security Monitor...

==========================================
 INSTALLATION COMPLETED
==========================================

USB Security Monitor is now active.
4. Verify installation directory

Run:

Get-ChildItem "C:\ProgramData\Taypro\USBSecurity"

You should have:

USB-SecurityAlert.ps1
settings.json
smtp-secret.dat
USBSecurity.log
5. Verify scheduled task
Get-ScheduledTask -TaskName "Taypro USB Security Monitor"

More detailed:

Get-ScheduledTask -TaskName "Taypro USB Security Monitor" |
    Select-Object TaskName, State, TaskPath

Expected:

TaskName                     : Taypro USB Security Monitor
State                        : Running
6. Verify task is running as SYSTEM
Get-ScheduledTask -TaskName "Taypro USB Security Monitor" |
    Select-Object -ExpandProperty Principal

You should see:

UserId       : SYSTEM
LogonType    : ServiceAccount
RunLevel     : Highest
7. Check startup log
Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

You should see:

TAYPRO USB SECURITY MONITOR STARTED

If you want to continuously watch the log:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Wait

Keep that PowerShell window open.

8. Test USB detection

With the log running:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Wait

Now physically insert a USB drive.

Wait a few seconds.

Expected:

USB DETECTED | Computer=XXXX

and then:

EMAIL SENT SUCCESSFULLY.

Press:

Ctrl + C

to stop watching the log.

9. Check the last 50 log entries
Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 50

You ideally want:

TAYPRO USB SECURITY MONITOR STARTED
USB DETECTED | Computer=...
EMAIL SENT SUCCESSFULLY.
10. Check scheduled-task execution result
Get-ScheduledTaskInfo -TaskName "Taypro USB Security Monitor"

Pay attention to:

LastRunTime
LastTaskResult

A successful task normally has:

LastTaskResult : 0
11. Verify the encrypted password exists
Test-Path "C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat"

Expected:

True

Check its size:

Get-Item "C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat" |
    Select-Object Name, Length

It should contain an encrypted Base64 value, not your actual SMTP password.

12. Test that the SYSTEM account can decrypt the credential

This is an important test because your scheduled task runs as SYSTEM.

First verify the secret can be decrypted under your administrator account:

Add-Type -AssemblyName System.Security

$EncryptedPassword = Get-Content `
    "C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat" `
    -Raw

$EncryptedBytes = [Convert]::FromBase64String(
    $EncryptedPassword.Trim()
)

$DecryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $EncryptedBytes,
    $null,
    [System.Security.Cryptography.DataProtectionScope]::LocalMachine
)

$TestPassword = [System.Text.Encoding]::UTF8.GetString(
    $DecryptedBytes
)

if (-not [string]::IsNullOrWhiteSpace($TestPassword)) {
    Write-Host "DPAPI DECRYPTION SUCCESSFUL" -ForegroundColor Green
}
else {
    Write-Host "DPAPI DECRYPTION FAILED" -ForegroundColor Red
}

$TestPassword = $null
$DecryptedBytes = $null
$EncryptedBytes = $null
$EncryptedPassword = $null

Do not print $TestPassword, because that would expose your SMTP password.

13. Test the monitor manually

Don't normally do this because the scheduled task should handle it, but for troubleshooting:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\Taypro\USBSecurity\USB-SecurityAlert.ps1"

If the script is designed to run continuously, leave it running and insert a USB.

If it produces an error, copy the error to me.

14. Test automatic startup

Now restart the laptop:

Restart-Computer

Do not manually start the USB monitor after reboot.

After Windows starts, open PowerShell as Administrator.

Run:

Get-ScheduledTask -TaskName "Taypro USB Security Monitor"

Then:

Get-ScheduledTaskInfo -TaskName "Taypro USB Security Monitor"

Then:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

You should see a new:

TAYPRO USB SECURITY MONITOR STARTED
15. Final USB test after reboot

Insert a USB.

Then:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

Expected:

TAYPRO USB SECURITY MONITOR STARTED
USB DETECTED | Computer=...
EMAIL SENT SUCCESSFULLY.

At this point you have verified:

                  TAYPRO USB SECURITY
                         │
                         ▼
                 Windows Startup
                         │
                         ▼
              Scheduled Task
                         │
                         ▼
                       SYSTEM
                         │
                         ▼
             USB-SecurityAlert.ps1
                         │
                 USB inserted?
                    /          \
                  NO            YES
                  │              │
                  │              ▼
                  │        Detect USB
                  │              │
                  │              ▼
                  │        Read encrypted
                  │        SMTP credential
                  │              │
                  │              ▼
                  │          DPAPI decrypt
                  │              │
                  │              ▼
                  │          Send email
                  │              │
                  │              ▼
                  └──────────> Log result
One-command diagnostic

If anything fails, run this single block and send me the output:

Write-Host "===== TASK =====" -ForegroundColor Cyan
Get-ScheduledTask -TaskName "Taypro USB Security Monitor" |
    Select-Object TaskName, State

Write-Host ""
Write-Host "===== TASK INFO =====" -ForegroundColor Cyan
Get-ScheduledTaskInfo -TaskName "Taypro USB Security Monitor"

Write-Host ""
Write-Host "===== FILES =====" -ForegroundColor Cyan
Get-ChildItem "C:\ProgramData\Taypro\USBSecurity" |
    Select-Object Name, Length, LastWriteTime

Write-Host ""
Write-Host "===== LOG =====" -ForegroundColor Cyan
Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

That will tell us immediately whether the problem is scheduled task, USB detection, DPAPI decryption, SMTP authentication, or email sending.
