@echo off
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "Logs" mkdir "Logs"
echo Checking PET CT SHEET local network configuration...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CHECK_LAN_CONFIG.ps1"
if errorlevel 1 (
  echo Network permissions missing. Windows administrator approval is required once.
  call "%~dp0FIX_SERVER_PERMISSION.bat"
  if errorlevel 1 goto FAILED
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CHECK_LAN_CONFIG.ps1"
  if errorlevel 1 goto FAILED
)
powershell.exe -NoProfile -Command "try {$r=Invoke-RestMethod 'http://127.0.0.1:300/api/health' -TimeoutSec 2;if($r.ok){exit 0}}catch{};exit 1"
if not errorlevel 1 goto OPEN
echo Starting PET CT SHEET server...
start "PET CT SHEET Server" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_SERVER_LOGGED.ps1"
set /a tries=0
:WAIT
timeout /t 1 /nobreak >nul
powershell.exe -NoProfile -Command "try {$r=Invoke-RestMethod 'http://127.0.0.1:300/api/health' -TimeoutSec 2;if($r.ok){exit 0}}catch{};exit 1"
if not errorlevel 1 goto OPEN
set /a tries+=1
if %tries% LSS 15 goto WAIT
goto FAILED
:OPEN
echo PET CT SHEET is running at http://127.0.0.1:300/
start "" "http://127.0.0.1:300/"
exit /b 0
:FAILED
echo.
echo SERVER FAILED. See Logs\lan-setup.log and Logs\server-error.log
if exist "Logs\lan-setup.log" powershell.exe -NoProfile -Command "Get-Content -LiteralPath 'Logs\lan-setup.log' -Tail 12"
if exist "Logs\server-error.log" powershell.exe -NoProfile -Command "Get-Content -LiteralPath 'Logs\server-error.log' -Tail 20"
pause
exit /b 1
