@echo off
setlocal
cd /d "%~dp0"
if not exist "Logs" mkdir "Logs"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest 'http://127.0.0.1:300/api/health' -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200 -and $r.Content -match 'ok'){exit 0} } catch {};exit 1"
if not errorlevel 1 goto OPEN
start "NuclearScan Server" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_SERVER_LOGGED.ps1"
set /a tries=0
:WAIT
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest 'http://127.0.0.1:300/api/health' -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200 -and $r.Content -match 'ok'){exit 0} } catch {};exit 1"
if not errorlevel 1 goto OPEN
set /a tries+=1
if %tries% GEQ 20 goto FAILED
timeout /t 1 /nobreak >nul
goto WAIT
:OPEN
start "" "http://127.0.0.1:300/"
exit /b 0
:FAILED
echo Server failed. Showing last error log:
if exist "Logs\server-error.log" powershell.exe -NoProfile -Command "Get-Content -LiteralPath 'Logs\server-error.log' -Tail 30"
echo.
echo Run DIAGNOSE_SERVER.bat and share the log to diagnose the exact cause.
pause
exit /b 1