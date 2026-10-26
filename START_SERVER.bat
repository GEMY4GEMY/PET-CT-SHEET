@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
if not exist "Logs" mkdir "Logs"
echo PET CT SHEET - Server TCP 500
set "LAN_IP="
for /f "usebackq delims=" %%I in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GET_LAN_IP.ps1" 2^>nul`) do if not defined LAN_IP set "LAN_IP=%%I"
if defined LAN_IP (echo COMPUTER LAN URL: http://!LAN_IP!:500/) else (echo WARNING: LAN IP not detected. Check network adapter.)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try {$h=Invoke-RestMethod 'http://127.0.0.1:500/api/health' -TimeoutSec 2;if($h.ok -and $h.port -eq 500 -and $h.service -eq 'PET_CT_SHEET'){exit 0}}catch{};exit 1"
if not errorlevel 1 goto OPEN
echo Starting new server...
start "PET CT SHEET Server 500" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_SERVER_LOGGED.ps1"
set /a tries=0
:WAIT
timeout /t 1 /nobreak >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try {$h=Invoke-RestMethod 'http://127.0.0.1:500/api/health' -TimeoutSec 2;if($h.ok -and $h.port -eq 500){exit 0}}catch{};exit 1"
if not errorlevel 1 goto OPEN
set /a tries+=1
if !tries! LSS 20 goto WAIT
echo ERROR: Server did not respond on TCP 500.
echo Check Logs\server-error.log and Logs\server-output.log
if exist "Logs\server-error.log" powershell.exe -NoProfile -Command "Get-Content 'Logs\server-error.log' -Tail 30"
if exist "Logs\server-output.log" powershell.exe -NoProfile -Command "Get-Content 'Logs\server-output.log' -Tail 15"
pause
exit /b 1
:OPEN
echo READY http://127.0.0.1:500/
if defined LAN_IP (
  echo LAN URL http://!LAN_IP!:500/
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try {$h=Invoke-RestMethod 'http://!LAN_IP!:500/api/health' -TimeoutSec 3;if($h.service -eq 'PET_CT_SHEET'){Write-Host 'LAN interface self-test OK';exit 0}}catch{Write-Host ('LAN self-test failed: '+$_.Exception.Message)};exit 1"
  if errorlevel 1 echo WARNING: Local LAN IP check failed. Run DIAGNOSE_SERVER.bat.
)
start "" "http://127.0.0.1:500/"
exit /b 0
