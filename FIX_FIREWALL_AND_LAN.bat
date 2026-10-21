@echo off
setlocal
cd /d "%~dp0"
echo =============================================
echo PET CT SHEET - Repair Firewall and LAN Access
echo =============================================
echo This configures HTTP port 300 and allows devices on your private local network.
echo Windows will ask for Administrator permission.
call "%~dp0FIX_SERVER_PERMISSION.bat"
if errorlevel 1 (
 echo.
 echo Repair failed. Please send Logs\lan-setup.log
 pause
 exit /b 1
)
echo.
echo Checking settings...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CHECK_LAN_CONFIG.ps1"
if errorlevel 1 (
 echo Verification failed. Please send Logs\lan-setup.log
 pause
 exit /b 1
)
echo.
echo LAN and Firewall settings verified.
echo Run START_SERVER.bat to start the server.
pause
exit /b 0
