powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null; Remove-Item '$env:TEMP\taypro.zip' -Force -ErrorAction SilentlyContinue; Remove-Item '$env:TEMP\taypro' -Recurse -Force -ErrorAction SilentlyContinue; Invoke-WebRequest 'https://github.com/vaibhavrandale/taypro-usb-security/archive/refs/heads/main.zip' -OutFile '$env:TEMP\taypro.zip'; Expand-Archive '$env:TEMP\taypro.zip' '$env:TEMP\taypro' -Force; & '$env:TEMP\taypro\taypro-usb-security-main\Install.ps1'; Write-Host ''; Write-Host '==========================================' -ForegroundColor Green; Write-Host ' TAYPRO USB SECURITY INSTALLATION COMPLETE' -ForegroundColor Green; Write-Host '==========================================' -ForegroundColor Green; Write-Host ''; Write-Host '===== LAST 30 LOG ENTRIES =====' -ForegroundColor Cyan; Get-Content 'C:\ProgramData\Taypro\USBSecurity\USBSecurity.log' -Tail 30"



Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30




Taypro USB Security Monitor

Windows USB security monitoring service for Taypro laptops.

The monitor:

Runs automatically when Windows starts.

Runs as the Windows SYSTEM account.

Detects USB storage-device insertion.

Records the computer name, logged-in user, drive letter, volume name, and timestamp.

Sends an email alert through the configured SMTP server.

Stores the SMTP password encrypted with Windows native DPAPI.

Does not use [System.Security.Cryptography.ProtectedData].

Stores application files under C:\ProgramData\Taypro\USBSecurity.

Uses a Windows Scheduled Task named Taypro USB Security Monitor.

1. Repository Structure

taypro-usb-security/
│
├── Install.ps1
├── USB-SecurityAlert.ps1
├── README.md
│
└── config/
    └── settings.json

After installation, the following files are created on the laptop:

C:\ProgramData\Taypro\USBSecurity\
│
├── USB-SecurityAlert.ps1
├── settings.json
├── smtp-secret.dat
└── USBSecurity.log

File purpose

File

Purpose

Install.ps1

Installs and configures the USB monitor

USB-SecurityAlert.ps1

Continuously monitors USB insertion

settings.json

SMTP and alert configuration

smtp-secret.dat

Encrypted SMTP password

USBSecurity.log

Security monitor log

2. Important Security Design

The SMTP password is not stored as plain text.

During installation:

SMTP password
      │
      ▼
Windows CryptProtectData()
      │
      ▼
Machine-level DPAPI
      │
      ▼
smtp-secret.dat

When the monitor starts:

smtp-secret.dat
      │
      ▼
Windows CryptUnprotectData()
      │
      ▼
SMTP password in memory
      │
      ▼
SMTP connection

The implementation directly uses the Windows crypt32.dll API.

It does not depend on:

[System.Security.Cryptography.ProtectedData]

Therefore, do not use the old ProtectedData installation/test commands from previous versions of this README.

3. Requirements

The target laptop must have:

Windows 10 or Windows 11

Windows PowerShell

Administrator privileges

Internet access during installation

Access to the configured SMTP server

SMTP mailbox credentials

The scheduled task runs as:

SYSTEM

with:

LogonType : ServiceAccount
RunLevel  : Highest

4. SMTP Configuration

Before installation, verify:

config/settings.json

Example:

{
  "SmtpServer": "smtp.hostinger.com",
  "SmtpPort": 465,
  "AuthUser": "your-mailbox@example.com",
  "From": "your-mailbox@example.com",
  "To": "security@example.com"
}

Do not put the SMTP password in settings.json.

The installer asks for the password interactively.

5. New Laptop Installation

Step 1 — Open PowerShell as Administrator

Open:

Start
→ PowerShell
→ Run as administrator

Confirm that the PowerShell window title shows Administrator.

Step 2 — Check PowerShell

Run:

$PSVersionTable.PSVersion

The installer is intended for Windows PowerShell.

Step 3 — Create the temporary folder

Run:

New-Item -ItemType Directory -Path C:\Temp -Force

Then:

Set-Location C:\Temp

6. Install Directly From GitHub

Run the following single command:

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://github.com/vaibhavrandale/taypro-usb-security/archive/refs/heads/main.zip' -OutFile $env:TEMP\taypro.zip; Remove-Item $env:TEMP\taypro -Recurse -Force -ErrorAction SilentlyContinue; Expand-Archive $env:TEMP\taypro.zip $env:TEMP\taypro -Force; & $env:TEMP\taypro\taypro-usb-security-main\Install.ps1"

The installer downloads the latest main branch and runs:

Install.ps1

7. Enter the SMTP Password

The installer asks:

Enter the Hostinger SMTP password

Enter the SMTP mailbox password.

The password is used to generate the encrypted:

C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat

The password is not written to settings.json.

8. Expected Installation Output

A successful installation should contain messages similar to:

Loading Windows native DPAPI support...
Windows native DPAPI loaded successfully.

Encrypting SMTP credential...
SMTP credential encrypted successfully.

Applying security permissions...
Security permissions configured.

Creating Windows startup task...
Scheduled task created successfully.

Starting USB Security Monitor...

The installer then displays the installation information.

The important result is:

USB Security Monitor is RUNNING.

If the monitor process is not detected, check the log before assuming installation succeeded.

9. Verify Installation Files

Run:

Get-ChildItem "C:\ProgramData\Taypro\USBSecurity"

You should see:

USB-SecurityAlert.ps1
settings.json
smtp-secret.dat
USBSecurity.log

You can also check the files individually:

Test-Path "C:\ProgramData\Taypro\USBSecurity\USB-SecurityAlert.ps1"

Test-Path "C:\ProgramData\Taypro\USBSecurity\settings.json"

Test-Path "C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat"

Test-Path "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log"

Each should return:

True

10. Verify the Scheduled Task

Run:

Get-ScheduledTask -TaskName "Taypro USB Security Monitor"

For a compact view:

Get-ScheduledTask -TaskName "Taypro USB Security Monitor" |
Select-Object TaskName, State, TaskPath

Expected:

TaskName                     State
--------                     -----
Taypro USB Security Monitor  Running

Important

Queued is not the desired steady state.

The monitor is a long-running PowerShell process, so after startup the task should normally remain running.

If the task is Queued, Ready, or immediately stops, inspect the log:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 50

11. Verify the Task Runs as SYSTEM

Run:

Get-ScheduledTask -TaskName "Taypro USB Security Monitor" |
Select-Object -ExpandProperty Principal

Expected:

UserId      : SYSTEM
LogonType   : ServiceAccount
RunLevel    : Highest

This is important because the USB monitor is designed to run independently of the currently logged-in Windows user.

12. Verify Scheduled Task Information

Run:

Get-ScheduledTaskInfo -TaskName "Taypro USB Security Monitor"

Look at:

LastRunTime
LastTaskResult
NextRunTime

A successful task execution normally reports:

LastTaskResult : 0

Note: a successful LastTaskResult only confirms that the scheduled task process started/ended successfully. The application log is the authoritative place to diagnose USB detection and SMTP errors.

13. Check the USB Security Log

Run:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

A successful monitor startup should contain:

TAYPRO USB SECURITY MONITOR STARTING
Windows native DPAPI loaded successfully.
Configuration loaded successfully.
SMTP credential decrypted successfully.
USB insertion event registered successfully.
TAYPRO USB SECURITY MONITOR STARTED
Waiting for USB storage device insertion...

The critical line is:

SMTP credential decrypted successfully.

If this line is missing, the monitor did not successfully decrypt the SMTP credential.

14. Continuously Watch the Log

To watch new log entries in real time:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Wait

Keep this PowerShell window open.

Press:

Ctrl + C

to stop watching the log.

15. Test USB Detection

With the log running:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Wait

Physically insert a USB storage device.

Wait a few seconds.

Expected log:

USB DETECTED | Computer=YOUR-COMPUTER

The complete entry should contain information similar to:

USB DETECTED | Computer=XXXX | User=DOMAIN\User | Drive=E:\ | Volume=USB

16. Test Email Sending

After USB detection, the monitor attempts to send the alert email.

Expected:

EMAIL SENT SUCCESSFULLY.

If email authentication or SMTP connection fails, you will see:

EMAIL FAILED: ...

The text after EMAIL FAILED: is the error that should be investigated.

For example:

EMAIL FAILED: The SMTP server requires a secure connection...

or:

EMAIL FAILED: Authentication unsuccessful...

17. Check the Last 50 Log Entries

Run:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 50

A successful USB test should contain:

TAYPRO USB SECURITY MONITOR STARTED
USB insertion event registered successfully.
USB DETECTED | Computer=...
EMAIL SENT SUCCESSFULLY.

18. Verify the Encrypted SMTP Credential

Check that the encrypted credential file exists:

Test-Path "C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat"

Expected:

True

Check its metadata:

Get-Item "C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat" |
Select-Object Name, Length, LastWriteTime

You should see a non-zero file length.

You can inspect the file if required:

Get-Content "C:\ProgramData\Taypro\USBSecurity\smtp-secret.dat"

It should contain an encrypted Base64 value.

Do not send or publish the contents of smtp-secret.dat.

19. Do NOT Use the Old ProtectedData Test

Do not run this:

Add-Type -AssemblyName System.Security

followed by:

[System.Security.Cryptography.ProtectedData]

and do not use:

[System.Security.Cryptography.ProtectedData]::Unprotect(...)

Those commands belong to the previous implementation.

The current implementation uses native Windows DPAPI through:

crypt32.dll

with:

CryptProtectData
CryptUnprotectData

20. Test the Monitor Manually

Normally, the Scheduled Task should run the monitor.

For troubleshooting only, you can run:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\Taypro\USBSecurity\USB-SecurityAlert.ps1"

If the script starts correctly, it should remain running and wait for USB insertion.

Open another PowerShell window and check:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

Then insert a USB.

If the manual execution produces an error, copy the error and the latest log entries for troubleshooting.

Press:

Ctrl + C

to stop the manually started monitor.

Do not leave a manually started copy running in production because the Scheduled Task is already responsible for running the monitor.

21. Test Automatic Startup After Reboot

This is the final important test.

Restart the laptop:

Restart-Computer

Do not manually start the USB monitor after Windows restarts.

Log into Windows.

Open PowerShell as Administrator.

Run:

Get-ScheduledTask -TaskName "Taypro USB Security Monitor" |
Select-Object TaskName, State, TaskPath

Then:

Get-ScheduledTaskInfo -TaskName "Taypro USB Security Monitor"

Then:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

You should see a new startup entry:

TAYPRO USB SECURITY MONITOR STARTING
...
TAYPRO USB SECURITY MONITOR STARTED

22. Final USB Test After Reboot

After reboot, insert a USB storage device.

Then run:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 30

Expected:

TAYPRO USB SECURITY MONITOR STARTED
USB DETECTED | Computer=...
EMAIL SENT SUCCESSFULLY.

At this point the following have been verified:

Windows startup
      │
      ▼
Scheduled Task
      │
      ▼
SYSTEM account
      │
      ▼
USB-SecurityAlert.ps1
      │
      ▼
USB insertion event
      │
      ▼
USB detected
      │
      ▼
Encrypted SMTP credential
      │
      ▼
Native Windows DPAPI decrypt
      │
      ▼
SMTP connection
      │
      ▼
Email alert
      │
      ▼
USBSecurity.log

23. One-Command Diagnostic

If anything fails, run this complete diagnostic block:

Write-Host "===== TASK =====" -ForegroundColor Cyan

Get-ScheduledTask `
    -TaskName "Taypro USB Security Monitor" `
    -ErrorAction SilentlyContinue |
    Select-Object TaskName, State, TaskPath

Write-Host ""
Write-Host "===== TASK PRINCIPAL =====" -ForegroundColor Cyan

Get-ScheduledTask `
    -TaskName "Taypro USB Security Monitor" `
    -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Principal

Write-Host ""
Write-Host "===== TASK INFO =====" -ForegroundColor Cyan

Get-ScheduledTaskInfo `
    -TaskName "Taypro USB Security Monitor" `
    -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "===== FILES =====" -ForegroundColor Cyan

Get-ChildItem `
    "C:\ProgramData\Taypro\USBSecurity" `
    -ErrorAction SilentlyContinue |
    Select-Object Name, Length, LastWriteTime

Write-Host ""
Write-Host "===== MONITOR PROCESS =====" -ForegroundColor Cyan

Get-CimInstance Win32_Process `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq "powershell.exe" -and
        $_.CommandLine -like "*USB-SecurityAlert.ps1*"
    } |
    Select-Object ProcessId, Name, CommandLine

Write-Host ""
Write-Host "===== LOG =====" -ForegroundColor Cyan

Get-Content `
    "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" `
    -Tail 50 `
    -ErrorAction SilentlyContinue

Send the output if troubleshooting is required.

24. Troubleshooting Guide

Problem: Task does not exist

Run the installer again as Administrator:

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://github.com/vaibhavrandale/taypro-usb-security/archive/refs/heads/main.zip' -OutFile $env:TEMP\taypro.zip; Remove-Item $env:TEMP\taypro -Recurse -Force -ErrorAction SilentlyContinue; Expand-Archive $env:TEMP\taypro.zip $env:TEMP\taypro -Force; & $env:TEMP\taypro\taypro-usb-security-main\Install.ps1"

Problem: Task is Queued

Check:

Get-ScheduledTaskInfo -TaskName "Taypro USB Security Monitor"

Then:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 50

Look for the first error after:

TAYPRO USB SECURITY MONITOR STARTING

Problem: SMTP password decryption fails

Look for:

ERROR decrypting SMTP password:

The exact message after that line is required for diagnosis.

Do not send the actual SMTP password.

Also verify that the laptop was reinstalled after changing the DPAPI implementation. An old smtp-secret.dat from another laptop must not be copied between machines.

Problem: ProtectedData error appears

If you see:

Unable to find type [System.Security.Cryptography.ProtectedData]

you are running an old copy of the monitor or installer.

Verify that the latest files are installed:

Select-String `
    -Path "C:\ProgramData\Taypro\USBSecurity\Install.ps1" `
    -Pattern "ProtectedData" `
    -ErrorAction SilentlyContinue

Normally Install.ps1 is not copied into the production directory, so also check the downloaded GitHub copy if necessary.

Check the monitor:

Select-String `
    -Path "C:\ProgramData\Taypro\USBSecurity\USB-SecurityAlert.ps1" `
    -Pattern "ProtectedData" `
    -ErrorAction SilentlyContinue

The current monitor should not use:

System.Security.Cryptography.ProtectedData

Problem: USB is detected but email fails

Check:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 50

Look for:

EMAIL FAILED:

Common areas to verify:

SMTP server

SMTP port

SMTP username

SMTP password

SSL requirement

Hostinger mailbox status

Network/firewall access

SMTP authentication policy

Do not put the SMTP password into settings.json.

Problem: USB is not detected

Check that the monitor reached:

USB insertion event registered successfully.

and:

TAYPRO USB SECURITY MONITOR STARTED

Then insert a USB storage device.

Check:

Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 50

25. Uninstall

To remove the scheduled task:

Unregister-ScheduledTask `
    -TaskName "Taypro USB Security Monitor" `
    -Confirm:$false

Then remove the installation directory:

Remove-Item `
    "C:\ProgramData\Taypro\USBSecurity" `
    -Recurse `
    -Force

Verify:

Get-ScheduledTask `
    -TaskName "Taypro USB Security Monitor" `
    -ErrorAction SilentlyContinue

No result means the scheduled task is removed.

26. Reinstallation

If the monitor needs to be reinstalled:

Open PowerShell as Administrator.

Run the GitHub one-command installer again.

Enter the SMTP password.

The existing scheduled task is removed.

The new monitor is installed.

A new machine-level encrypted SMTP credential is generated.

The scheduled task is recreated.

The monitor is started.

Check the log.

Installation command:

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://github.com/vaibhavrandale/taypro-usb-security/archive/refs/heads/main.zip' -OutFile $env:TEMP\taypro.zip; Remove-Item $env:TEMP\taypro -Recurse -Force -ErrorAction SilentlyContinue; Expand-Archive $env:TEMP\taypro.zip $env:TEMP\taypro -Force; & $env:TEMP\taypro\taypro-usb-security-main\Install.ps1"

27. Production Verification Checklist

Before considering a laptop successfully deployed, verify:

[ ] PowerShell opened as Administrator
[ ] Installation completed
[ ] settings.json exists
[ ] smtp-secret.dat exists
[ ] USBSecurity.log exists
[ ] Scheduled Task exists
[ ] Scheduled Task runs as SYSTEM
[ ] Task RunLevel is Highest
[ ] Monitor process is running
[ ] Native Windows DPAPI loaded successfully
[ ] SMTP credential decrypted successfully
[ ] USB insertion event registered successfully
[ ] USB detection tested
[ ] Email alert received
[ ] Laptop rebooted
[ ] Scheduled Task started automatically
[ ] USB detection tested again after reboot
[ ] Email alert received after reboot

28. Expected Final State

The final laptop should have:

Windows
   │
   ├── Startup
   │      │
   │      ▼
   │  Scheduled Task
   │  "Taypro USB Security Monitor"
   │      │
   │      ├── User: SYSTEM
   │      ├── RunLevel: Highest
   │      └── AtStartup
   │
   ▼
USB-SecurityAlert.ps1
   │
   ├── Native Windows DPAPI
   │
   ├── USB event monitoring
   │
   ├── SMTP email
   │
   └── USBSecurity.log

The monitor should require no manual start after installation or reboot.
