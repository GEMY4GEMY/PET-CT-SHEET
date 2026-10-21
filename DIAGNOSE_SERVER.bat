@echo off
cd /d "%~dp0"
echo === SERVER PORT ===
netstat -ano | findstr ":300"
echo === LAN IPv4 ADDRESS ===
ipconfig | findstr /i "IPv4"
echo === PORT 300 URL RESERVATION ===
netsh http show urlacl url=http://+:300/
echo === PORT 300 FIREWALL RULE ===
powershell.exe -NoProfile -Command "Get-NetFirewallRule -DisplayName 'PET CT SHEET LAN TCP 300' -ErrorAction SilentlyContinue | Format-Table DisplayName,Enabled,Profile,Action"
echo === POWERSHELL VERSION ===
powershell.exe -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
echo === FILES ===
dir Server.ps1 index.html Data
echo === SERVER ERROR ===
if exist "Logs\server-error.log" powershell.exe -NoProfile -Command "Get-Content -LiteralPath 'Logs\server-error.log' -Tail 50"
echo === HTTP HEALTH ===
powershell.exe -NoProfile -Command "try {(Invoke-WebRequest 'http://127.0.0.1:300/api/health' -UseBasicParsing -TimeoutSec 3).Content} catch {$_.Exception.Message}"
pause