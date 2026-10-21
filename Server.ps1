$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$data=Join-Path $root 'Data'; $backups=Join-Path $root 'Backups'
New-Item -ItemType Directory -Force -Path $data,$backups | Out-Null
$db=Join-Path $data 'bookings.json'
if(!(Test-Path $db)){[IO.File]::WriteAllText($db,'[]',[Text.UTF8Encoding]::new($false))}
$mutex=New-Object Threading.Mutex($false,'Local\NuclearScan300DB')
function Read-Records { $raw=[IO.File]::ReadAllText($db,[Text.Encoding]::UTF8); if([string]::IsNullOrWhiteSpace($raw)){return ,@()}; $parsed=ConvertFrom-Json -InputObject $raw; if($null -eq $parsed){return ,@()}; return ,@($parsed) }
function Write-Records($records) {
 $json=ConvertTo-Json -InputObject @($records) -Depth 30 -Compress
 $tmp="$db.tmp";[IO.File]::WriteAllText($tmp,$json,[Text.UTF8Encoding]::new($false));Move-Item -Force $tmp $db
}
function Send($ctx,[byte[]]$bytes,$type='application/json; charset=utf-8',$code=200,$filename='') {
 $res=$ctx.Response;$res.StatusCode=$code;$res.ContentType=$type;$res.Headers.Add('Cache-Control','no-store');$res.Headers.Add('X-Content-Type-Options','nosniff')
 if($filename){$res.Headers.Add('Content-Disposition',"attachment; filename=$filename")}
 $res.ContentLength64=$bytes.Length;$res.OutputStream.Write($bytes,0,$bytes.Length);$res.Close()
}
function Json-Bytes($obj){return [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $obj -Depth 30 -Compress))}
function Backup-Now {
 $name='backup_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff');$folder=Join-Path $backups $name
 New-Item -ItemType Directory -Force -Path $folder | Out-Null
 Copy-Item $db (Join-Path $folder 'bookings.json')
 if(Test-Path $settingsFile){Copy-Item $settingsFile (Join-Path $folder 'settings.json')}
 return $folder
}
$settingsFile=Join-Path $data 'settings.json'
if(!(Test-Path $settingsFile)){[IO.File]::WriteAllText($settingsFile,'{}',(New-Object Text.UTF8Encoding($false)))}
$listener=[Net.HttpListener]::new();$listener.Prefixes.Add('http://127.0.0.1:300/');try { $listener.Start() } catch { throw ('Cannot listen on port 300: '+$_.Exception.Message+' | Check port and Windows URL permissions') }
Write-Host 'Nuclear Scan: http://localhost:300'
$lastBackup=Get-Date
try { $null=$mutex.WaitOne(); try { $null=Backup-Now; $lastBackup=Get-Date } finally { $mutex.ReleaseMutex() } } catch { Write-Warning $_ }
try {
 while($listener.IsListening){
  if(((Get-Date)-$lastBackup).TotalHours -ge 24){$null=$mutex.WaitOne();try{$null=Backup-Now;$lastBackup=Get-Date}finally{$mutex.ReleaseMutex()}}
  $ctx=$listener.GetContext()
  try {
   $path=$ctx.Request.Url.AbsolutePath;$method=$ctx.Request.HttpMethod
   if($path -eq '/' -and $method -eq 'GET'){Send $ctx ([IO.File]::ReadAllBytes((Join-Path $root 'index.html'))) 'text/html; charset=utf-8';continue}
   if($path -eq '/api/health'){Send $ctx (Json-Bytes @{ok=$true;port=300});continue}
   if($path -eq '/api/settings' -and $method -eq 'GET'){
    Send $ctx ([IO.File]::ReadAllBytes($settingsFile));continue
   }
   if($path -eq '/api/settings' -and $method -eq 'POST'){
    if($ctx.Request.ContentLength64 -gt 262144){throw 'Settings too large'}
    $reader=[IO.StreamReader]::new($ctx.Request.InputStream,[Text.Encoding]::UTF8)
    $raw=$reader.ReadToEnd();$reader.Close()
    $null=ConvertFrom-Json -InputObject $raw -ErrorAction Stop
    $tmp=$settingsFile+'.tmp'
    [IO.File]::WriteAllText($tmp,$raw,(New-Object Text.UTF8Encoding($false)))
    Move-Item -Force $tmp $settingsFile
    Send $ctx (Json-Bytes @{ok=$true});continue
   }
   if($path -eq '/api/bookings' -and $method -eq 'GET'){
    $null=$mutex.WaitOne();try{$items=Read-Records}finally{$mutex.ReleaseMutex()}
    $items=@($items|Sort-Object -Property @{Expression={$_.d.date};Descending=$true},@{Expression={$_.id};Descending=$true})
    Send $ctx (Json-Bytes $items);continue
   }
   if($path -eq '/api/backups' -and $method -eq 'GET'){
    $items=@(Get-ChildItem $backups -Directory -Filter 'backup_*' | Sort-Object Name -Descending | ForEach-Object { @{name=$_.Name;date=$_.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')} })
    Send $ctx (Json-Bytes $items);continue
   }
   if($path -eq '/api/restore' -and $method -eq 'POST'){
    if($ctx.Request.ContentLength64 -gt 8192){throw 'Restore request too large'}
    $reader=[IO.StreamReader]::new($ctx.Request.InputStream,[Text.Encoding]::UTF8)
    $payload=ConvertFrom-Json -InputObject $reader.ReadToEnd();$reader.Close()
    $name=[string]$payload.name
    if($name -notmatch '^backup_[0-9]{8}_[0-9]{6}_[0-9]{3}$'){throw 'Invalid backup name'}
    $folder=Join-Path $backups $name
    if(!(Test-Path (Join-Path $folder 'bookings.json'))){throw 'Backup not found'}
    $null=$mutex.WaitOne()
    try{
     $null=Backup-Now
     $newRecords=[IO.File]::ReadAllText((Join-Path $folder 'bookings.json'),[Text.Encoding]::UTF8)
     $null=ConvertFrom-Json -InputObject $newRecords -ErrorAction Stop
     [IO.File]::WriteAllText(($db+'.tmp'),$newRecords,[Text.UTF8Encoding]::new($false));Move-Item -Force ($db+'.tmp') $db
     if(Test-Path (Join-Path $folder 'settings.json')){
      $newSettings=[IO.File]::ReadAllText((Join-Path $folder 'settings.json'),[Text.Encoding]::UTF8)
      $null=ConvertFrom-Json -InputObject $newSettings -ErrorAction Stop
      [IO.File]::WriteAllText(($settingsFile+'.tmp'),$newSettings,[Text.UTF8Encoding]::new($false));Move-Item -Force ($settingsFile+'.tmp') $settingsFile
     }
     $lastBackup=Get-Date
    }finally{$mutex.ReleaseMutex()}
    Send $ctx (Json-Bytes @{ok=$true;restored=$name});continue
   }
   if($path -eq '/api/backup' -and $method -eq 'GET'){
    $null=$mutex.WaitOne();try{$file=Backup-Now}finally{$mutex.ReleaseMutex()}
    $zip=Join-Path $env:TEMP ('PET_CT_SHEET_'+[guid]::NewGuid().ToString('N')+'.zip')
    Compress-Archive -Path (Join-Path $file '*') -DestinationPath $zip
    try{Send $ctx ([IO.File]::ReadAllBytes($zip)) 'application/zip' 200 ((Split-Path $file -Leaf)+'.zip')}finally{Remove-Item $zip -ErrorAction SilentlyContinue};continue
   }
   if($path -eq '/api/bookings/update' -and $method -eq 'POST'){
    if($ctx.Request.ContentLength64 -gt 2097152){throw 'Request too large'}
    $reader=[IO.StreamReader]::new($ctx.Request.InputStream,[Text.Encoding]::UTF8)
    $payload=ConvertFrom-Json -InputObject $reader.ReadToEnd();$reader.Close()
    if(!$payload.id -or !$payload.d){throw 'Missing booking ID or data'}
    if($payload.d.phone -and [string]$payload.d.phone -notmatch '^[0-9]{11}$'){throw 'Invalid phone'}
    $null=$mutex.WaitOne()
    try{
     $records=Read-Records;$found=$false
     foreach($record in $records){if([string]$record.id -eq [string]$payload.id){$record.d=$payload.d;$found=$true;break}}
     if(!$found){throw 'Booking not found'}
     $null=Backup-Now
     Write-Records $records
    }finally{$mutex.ReleaseMutex()}
    Send $ctx (Json-Bytes @{ok=$true;updated=$payload.id});continue
   }
   if($path -in @('/api/bookings','/api/import') -and $method -eq 'POST'){
    if($ctx.Request.ContentLength64 -gt 2097152){throw 'Request too large'}
    $reader=[IO.StreamReader]::new($ctx.Request.InputStream,[Text.Encoding]::UTF8)
    $payload=ConvertFrom-Json -InputObject $reader.ReadToEnd();$reader.Close()
    $incoming=@($payload)
    $added=0;$null=$mutex.WaitOne()
    try{
     $records=Read-Records
     foreach($item in $incoming){
      if(!$item.d){continue}
      $phone=[string]$item.d.phone
      if($phone -and $phone -notmatch '^[0-9]{11}$'){continue}
      if($path -eq '/api/import' -and @($records|Where-Object { $_.old_id -eq [string]$item.id }).Count){continue}
      $newid=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()+'_'+[guid]::NewGuid().ToString('N').Substring(0,6)
      $records+=@{id=$newid;old_id=$(if($path -eq '/api/import'){[string]$item.id}else{''});d=$item.d};$added++
     }
     Write-Records $records
     if(((Get-Date)-$lastBackup).TotalHours -ge 24){$null=Backup-Now;$lastBackup=Get-Date}
    }finally{$mutex.ReleaseMutex()}
    Send $ctx (Json-Bytes @{imported=$added});continue
   }
   Send $ctx (Json-Bytes @{error='Not found'}) 'application/json; charset=utf-8' 404
  }catch{
   try{Send $ctx (Json-Bytes @{error=$_.Exception.Message}) 'application/json; charset=utf-8' 400}catch{}
  }
 }
}finally{$listener.Stop();$listener.Close();$mutex.Dispose()}
