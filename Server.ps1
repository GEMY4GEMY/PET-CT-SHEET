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
 $name='bookings_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.json';$path=Join-Path $backups $name
 Copy-Item $db $path
 return $path
}
$settingsFile=Join-Path $data 'settings.json'
if(!(Test-Path $settingsFile)){[IO.File]::WriteAllText($settingsFile,'{}',(New-Object Text.UTF8Encoding($false)))}
$listener=[Net.HttpListener]::new();$listener.Prefixes.Add('http://127.0.0.1:300/');try { $listener.Start() } catch { throw ('Cannot listen on port 300: '+$_.Exception.Message+' | Check port and Windows URL permissions') }
Write-Host 'Nuclear Scan: http://localhost:300'
$lastBackup=Get-Date
try { $null=$mutex.WaitOne(); try { $null=Backup-Now; $lastBackup=Get-Date } finally { $mutex.ReleaseMutex() } } catch { Write-Warning $_ }
try {
 while($listener.IsListening){
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
    $reader=New-Object IO.StreamReader($ctx.Request.InputStream,[Text.Encoding]::UTF8)
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
   if($path -eq '/api/backup' -and $method -eq 'GET'){
    $null=$mutex.WaitOne();try{$file=Backup-Now}finally{$mutex.ReleaseMutex()}
    Send $ctx ([IO.File]::ReadAllBytes($file)) 'application/octet-stream' 200 ([IO.Path]::GetFileName($file));continue
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
