@echo off
setlocal
cd /d "%~dp0"
if not exist "Logs" mkdir "Logs"
if not exist "Logs\\lan-port300-ready.flag" (
 echo First-time LAN setup requires administrator approval for port 300.
 call "%~dp0FIX_SERVER_PERMISSION.bat"
 if errorlevel 1 goto FAILED
 echo ready>"Logs\\lan-port300-ready.flag"
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest 'http://127.0.0.1:300/api/health' -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200 -and $r.Content -match 'ok'){exit 0} } catch {};exit 1"
if not errorlevel 1 goto OPEN
start "NuclearScan Server" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_SERVER_LOGGED.ps1"
set /a tries=0
:WAIT
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest 'http://127.0.0.1:300/api/health' -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200 -and $r.Content -match 'ok'){exit 0} } catch {};exit 1"
if not errorlevel 1 goto OPEN
set /a tries+=1
if %tries% GEQ 10 goto CHECK_PERMISSION
timeout /t 1 /nobreak >nul
goto WAIT
:CHECK_PERMISSION
findstr /i /c:"Access is denied" "Logs\server-error.log" >nul 2>&1
if errorlevel 1 goto FAILED
echo.
echo Windows denied permission to listen on local port 300.
echo A one-time administrator confirmation is required to fix the URL reservation.
call "%~dp0FIX_SERVER_PERMISSION.bat"
if errorlevel 1 goto FAILED
echo ready>"Logs\\lan-port300-ready.flag"
echo Retrying server startup...
start "NuclearScan Server" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_SERVER_LOGGED.ps1"
set /a tries=0
:RETRY
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest 'http://127.0.0.1:300/api/health' -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200 -and $r.Content -match 'ok'){exit 0} } catch {};exit 1"
if not errorlevel 1 goto OPEN
set /a tries+=1
if %tries% GEQ 10 goto FAILED
timeout /t 1 /nobreak >nul
goto RETRY
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