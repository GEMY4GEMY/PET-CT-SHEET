$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$logs=Join-Path $root 'Logs';New-Item -ItemType Directory -Force $logs | Out-Null
$lock=New-Object Threading.Mutex($false,'Local\NuclearScan300Watchdog')
if(!$lock.WaitOne(0)){exit 0}
try {
 while($true){
  $healthy=$false
  try {$r=Invoke-WebRequest 'http://127.0.0.1:18763/api/health' -UseBasicParsing -TimeoutSec 3;$healthy=($r.StatusCode -eq 200 -and $r.Content -match '"ok"') }catch{}
  if(!$healthy){
   try {Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+(Join-Path $root 'RUN_SERVER_LOGGED.ps1')+'"')) -WindowStyle Hidden}
   catch {Add-Content (Join-Path $logs 'watchdog.log') "$(Get-Date -Format s) $($_.Exception.Message)"}
  }
  Start-Sleep -Seconds 20
 }
}finally{$lock.ReleaseMutex();$lock.Dispose()}