$ErrorActionPreference='Stop'
$log=Join-Path $PSScriptRoot 'Logs'
New-Item -ItemType Directory -Force -Path $log | Out-Null
$logfile=Join-Path $log 'urlacl-setup.log'
$url='http://127.0.0.1:300/'
try {
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 $principal=[Security.Principal.WindowsPrincipal]::new($identity)
 if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Administrator approval is required'}
 $sid='S-1-5-32-545' # Built-in local Users group; loopback-only URL
 $sddl='D:(A;;GX;;;'+$sid+')'
 $existing=(& netsh http show urlacl url=$url 2>&1 | Out-String)
 if($LASTEXITCODE -eq 0 -and $existing -match [regex]::Escape($sid)){Write-Host 'HTTP permission already assigned to this Windows user.';exit 0}
 if($LASTEXITCODE -eq 0){throw 'An existing URL reservation belongs to another user. Refusing to overwrite it. Check: netsh http show urlacl url=http://127.0.0.1:300/'}
 $output=(& netsh http add urlacl url=$url sddl=$sddl 2>&1 | Out-String)
 if($LASTEXITCODE -ne 0){throw ('Unable to register HTTP URL: '+$output)}
 $verify=(& netsh http show urlacl url=$url 2>&1 | Out-String)
 if($LASTEXITCODE -ne 0 -or $verify -notmatch [regex]::Escape($sid)){throw 'Permission verification failed'}
 ('SUCCESS '+(Get-Date -Format s)+' '+$url+' '+$sid) | Out-File $logfile -Append -Encoding UTF8
 Write-Host 'HTTP permission configured. You can now run START_SERVER.bat normally.'
 exit 0
} catch {
 ('FAILED '+(Get-Date -Format s)+' '+$_.Exception.Message) | Out-File $logfile -Append -Encoding UTF8
 Write-Host ('HTTP setup failed: '+$_.Exception.Message)
 exit 1
}
