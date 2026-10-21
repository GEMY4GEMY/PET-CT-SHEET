$ErrorActionPreference='Stop'
$log=Join-Path $PSScriptRoot 'Logs'
New-Item -ItemType Directory -Force -Path $log | Out-Null
$logfile=Join-Path $log 'urlacl-setup.log'
$url='http://+:300/'
$ruleName='PET CT SHEET LAN TCP 300'
try {
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 $principal=[Security.Principal.WindowsPrincipal]::new($identity)
 if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Administrator approval is required'}
 # Grant HTTP.sys URL access to local authenticated Windows users only.
 $sid='S-1-5-32-545'
 $sddl='D:(A;;GX;;;'+$sid+')'
 $existing=(& netsh http show urlacl url=$url 2>&1 | Out-String)
 if($LASTEXITCODE -eq 0){
  if($existing -notmatch [regex]::Escape($sid)){throw ('Existing URL reservation for '+$url+' is owned by another identity. Refusing to overwrite it.')}
  Write-Host 'HTTP URL reservation already exists for local Users.'
 } else {
  $output=(& netsh http add urlacl url=$url sddl=$sddl 2>&1 | Out-String)
  if($LASTEXITCODE -ne 0){throw ('Unable to reserve HTTP URL: '+$output)}
 }
 $verify=(& netsh http show urlacl url=$url 2>&1 | Out-String)
 if($LASTEXITCODE -ne 0 -or $verify -notmatch [regex]::Escape($sid)){throw 'HTTP URL reservation verification failed'}
 # Restrict access to devices on the local subnet and Private Windows network profile.
 $existingRule=Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
 if($existingRule){Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop}
 New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 300 -Profile Private -RemoteAddress LocalSubnet -Enabled True -ErrorAction Stop | Out-Null
 ('SUCCESS '+(Get-Date -Format s)+' '+$url+' firewall Private LocalSubnet') | Out-File $logfile -Append -Encoding UTF8
 Write-Host 'LAN access configured on port 300 (Private network, local subnet only).'
 Write-Host 'Start the program normally with START_SERVER.bat.'
 exit 0
} catch {
 ('FAILED '+(Get-Date -Format s)+' '+$_.Exception.Message) | Out-File $logfile -Append -Encoding UTF8
 Write-Host ('LAN setup failed: '+$_.Exception.Message)
 exit 1
}
