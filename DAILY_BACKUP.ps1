$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$data=Join-Path $root 'Data'
$backups=Join-Path $root 'Backups'
$logs=Join-Path $root 'Logs'
New-Item -ItemType Directory -Force -Path $data,$backups,$logs | Out-Null
$db=Join-Path $data 'bookings.json'
if(!(Test-Path -LiteralPath $db)){ throw 'No bookings database yet. Start the server first.' }
$mutex=New-Object System.Threading.Mutex($false,'Local\NuclearScan18763DB')
$locked=$false
try {
 $locked=$mutex.WaitOne(15000)
 if(!$locked){throw 'Database busy; retry later'}
 $day=Get-Date -Format 'yyyy-MM-dd'
 $dest=Join-Path $backups ('bookings_'+$day+'.json')
 $temp=$dest+'.tmp'
 Copy-Item -LiteralPath $db -Destination $temp -Force
 $raw=[IO.File]::ReadAllText($temp,[Text.Encoding]::UTF8)
 $null=ConvertFrom-Json -InputObject $raw -ErrorAction Stop
 Move-Item -LiteralPath $temp -Destination $dest -Force
 $settings=Join-Path $data 'settings.json'
 if(Test-Path $settings){Copy-Item -LiteralPath $settings -Destination (Join-Path $backups ('settings_'+$day+'.json')) -Force}
 Add-Content -LiteralPath (Join-Path $logs 'backup.log') -Value "$(Get-Date -Format s) SUCCESS $dest"
} catch {
 Add-Content -LiteralPath (Join-Path $logs 'backup.log') -Value "$(Get-Date -Format s) FAILED $($_.Exception.Message)"
 throw
} finally {if($locked){$mutex.ReleaseMutex()};$mutex.Dispose()}