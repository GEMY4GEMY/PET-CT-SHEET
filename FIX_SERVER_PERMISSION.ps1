$ErrorActionPreference='Stop'
$logDir=Join-Path $PSScriptRoot 'Logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile=Join-Path $logDir 'lan-setup.log'
$url='http://+:300/'
$ruleName='PET CT SHEET LAN TCP 300'
function Log($message) {
 $line='['+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+'] '+$message
 Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
 Write-Host $message
}
try {
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 $principal=New-Object Security.Principal.WindowsPrincipal($identity)
 if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Please approve the Windows administrator prompt (UAC).'}
 Log 'Checking port 300 HTTP.sys reservation...'
 $sid='S-1-5-32-545'
 $sddl='D:(A;;GX;;;'+$sid+')'
 $existing=(& netsh.exe http show urlacl url=$url 2>&1 | Out-String)
 # netsh can return exit code 0 and print only a heading even when no URL is reserved.
 if($existing -match [regex]::Escape($url)){
  if($existing -notmatch [regex]::Escape($sid)){
   throw 'Port 300 URL reservation already exists for another account. No existing Windows reservation was removed. Send the diagnostic output for safe resolution.'
  }
  Log 'HTTP reservation already present.'
 } else {
  $added=(& netsh.exe http add urlacl url=$url sddl=$sddl 2>&1 | Out-String)
  if($LASTEXITCODE -ne 0){throw ('Could not add URL reservation: '+$added)}
  Log 'HTTP reservation created.'
 }
 $verify=(& netsh.exe http show urlacl url=$url 2>&1 | Out-String)
 if($verify -notmatch [regex]::Escape($url) -or $verify -notmatch [regex]::Escape($sid)){throw ('HTTP reservation verification failed: '+$verify)}
 Log 'Configuring firewall for TCP 300, Private profile, local subnet...'
 $existingRule=Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
 if($existingRule){$existingRule | Remove-NetFirewallRule -ErrorAction Stop}
 New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 300 -Profile Private -RemoteAddress LocalSubnet -Enabled True -ErrorAction Stop | Out-Null
 $rule=Get-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
 if($rule.Enabled -ne 'True' -or $rule.Action -ne 'Allow'){throw 'Firewall rule verification failed.'}
 $ip=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notmatch '^(127\\.|169\\.254\\.)'} | Select-Object -ExpandProperty IPAddress)
 Log ('SUCCESS. LAN URL: http://'+($ip -join ':300/ or http://')+':300/')
 Log 'Firewall: Private network and LocalSubnet only. No public Internet exposure configured.'
 exit 0
} catch {
 Log ('FAILED: '+$_.Exception.Message)
 exit 1
}
