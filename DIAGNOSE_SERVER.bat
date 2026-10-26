@echo off
cd /d "%~dp0"
echo === TCP PORT 500 ===
netstat -ano | findstr ":500"
echo === DETECTED COMPUTER LAN IP ===
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GET_LAN_IP.ps1"
echo === ALL LOCAL IPv4 ===
ipconfig | findstr /i "IPv4"
echo === NETWORK PROFILE ===
powershell.exe -NoProfile -Command "Get-NetConnectionProfile | Format-Table InterfaceAlias,NetworkCategory"
echo === FIREWALL ===
powershell.exe -NoProfile -Command "Get-NetFirewallRule -DisplayName 'PET CT SHEET LAN TCP 500' -ErrorAction SilentlyContinue | Format-Table DisplayName,Enabled,Profile,Action"
echo === LISTENING PORT DETAILS ===
powershell.exe -NoProfile -Command "Get-NetTCPConnection -LocalPort 500 -State Listen -ErrorAction SilentlyContinue | Format-Table LocalAddress,LocalPort,OwningProcess"
echo === SERVER ERRORS ===
if exist "Logs\server-error.log" powershell.exe -NoProfile -Command "Get-Content 'Logs\server-error.log' -Tail 40"
echo === SERVER OUTPUT ===
if exist "Logs\server-output.log" powershell.exe -NoProfile -Command "Get-Content 'Logs\server-output.log' -Tail 20"
echo === HEALTH ===
powershell.exe -NoProfile -Command "try {(Invoke-RestMethod 'http://127.0.0.1:500/api/health' -TimeoutSec 3)|ConvertTo-Json -Compress}catch{$_.Exception.Message}"
pause
