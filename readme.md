7. New laptop installation
On the new laptop, install Git first.
Then open PowerShell as Administrator:
cd C:\Temp
Clone:
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://github.com/vaibhavrandale/taypro-usb-security/archive/refs/heads/main.zip' -OutFile $env:TEMP\taypro.zip; Expand-Archive $env:TEMP\taypro.zip $env:TEMP\taypro -Force; & $env:TEMP\taypro\taypro-usb-security-main\Install.ps1"
Enter:
cd .\taypro-usb-security
Then:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install.ps1"
It asks:
Enter the Hostinger SMTP password
Enter the mailbox password.
Then installation is finished.
vaibhavrandale has 11 repositories available. Follow their code on GitHub.
 
9. Testing after installation
After Install.ps1 finishes:
Get-ScheduledTask -TaskName "Taypro USB Security Monitor"
Then:
Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 20
You should see:
TAYPRO USB SECURITY MONITOR STARTED
Now insert a USB.
Check:
Get-Content "C:\ProgramData\Taypro\USBSecurity\USBSecurity.log" -Tail 20
Expected:
USB DETECTED | Computer=...
EMAIL SENT SUCCESSFULLY.
 
 
