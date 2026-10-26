@echo off
setlocal
cd /d "%~dp0"
echo PET CT SHEET - Allow LAN access on TCP port 300
echo This step only changes a Windows Firewall rule. It does not modify bookings.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$f=Join-Path (Get-Location) 'SETUP_LAN_FIREWALL.ps1';$p=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$f+'"')) -Verb RunAs -Wait -PassThru;exit $p.ExitCode"
if errorlevel 1 (
 echo Firewall setup failed. See Logs\lan-setup.log
 pause
 exit /b 1
)
echo LAN firewall setup completed. Now run START_SERVER.bat.
pause
exit /b 0
