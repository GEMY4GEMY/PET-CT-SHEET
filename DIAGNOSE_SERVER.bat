@echo off
cd /d "%~dp0"
echo === TCP PORT 300 ===
netstat -ano | findstr ":300"
echo === LOCAL IPv4 ===
ipconfig | findstr /i "IPv4"
echo === NETWORK PROFILE ===
powershell.exe -NoProfile -Command "Get-NetConnectionProfile | Format-Table InterfaceAlias,NetworkCategory"
echo === FIREWALL ===
powershell.exe -NoProfile -Command "Get-NetFirewallRule -DisplayName 'PET CT SHEET LAN TCP 300' -ErrorAction SilentlyContinue | Format-Table DisplayName,Enabled,Profile,Action"
echo === SERVER ERRORS ===
if exist "Logs\server-error.log" powershell.exe -NoProfile -Command "Get-Content 'Logs\server-error.log' -Tail 40"
echo === SERVER OUTPUT ===
if exist "Logs\server-output.log" powershell.exe -NoProfile -Command "Get-Content 'Logs\server-output.log' -Tail 20"
echo === HEALTH ===
powershell.exe -NoProfile -Command "try {(Invoke-RestMethod 'http://127.0.0.1:300/api/health' -TimeoutSec 3)|ConvertTo-Json -Compress}catch{$_.Exception.Message}"
pause
