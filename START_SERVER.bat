@echo off
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "Logs" mkdir "Logs"
echo PET CT SHEET - Starting local server on port 300...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try {$h=Invoke-RestMethod 'http://127.0.0.1:300/api/health' -TimeoutSec 2;if($h.ok){exit 0}}catch{};exit 1"
if not errorlevel 1 goto OPEN
start "PET CT SHEET Server" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_SERVER_LOGGED.ps1"
set /a tries=0
:WAIT
timeout /t 1 /nobreak >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try {$h=Invoke-RestMethod 'http://127.0.0.1:300/api/health' -TimeoutSec 2;if($h.ok){exit 0}}catch{};exit 1"
if not errorlevel 1 goto OPEN
set /a tries+=1
if %tries% LSS 15 goto WAIT
echo.
echo SERVER FAILED. Port 300 may be used by another application.
echo Read Logs\server-error.log or run DIAGNOSE_SERVER.bat.
if exist "Logs\server-error.log" powershell.exe -NoProfile -Command "Get-Content 'Logs\server-error.log' -Tail 25"
pause
exit /b 1
:OPEN
echo SERVER READY: http://127.0.0.1:300/
start "" "http://127.0.0.1:300/"
exit /b 0
