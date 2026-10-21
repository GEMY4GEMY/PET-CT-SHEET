@echo off
setlocal
cd /d "%~dp0"
echo PET CT SHEET requires one-time Windows administrator approval to register the local HTTP address.
echo No patient records or settings will be changed.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path (Get-Location) 'FIX_SERVER_PERMISSION.ps1')+'"')) -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
if errorlevel 1 (
 echo Permission setup did not complete. See Logs\urlacl-setup.log
 exit /b 1
)
echo Permission setup completed.
exit /b 0
