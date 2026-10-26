$ErrorActionPreference='Stop'
try {
 $url='http://+:300/'
 $res=(& netsh.exe http show urlacl url=$url 2>&1 | Out-String)
 if($res -notmatch [regex]::Escape($url)){Write-Host 'MISSING: HTTP.sys URL reservation for port 300';exit 1}
 $rule=@(Get-NetFirewallRule -DisplayName 'PET CT SHEET LAN TCP 300' -ErrorAction SilentlyContinue | Where-Object {$_.Enabled -eq 'True' -and $_.Action -eq 'Allow'})
 if($rule.Count -eq 0){Write-Host 'MISSING: enabled Windows Firewall allow rule for port 300';exit 1}
 $ok=$false
 foreach($item in $rule){
  $port=$item | Get-NetFirewallPortFilter
  $address=$item | Get-NetFirewallAddressFilter
  if(([string]$port.Protocol -eq 'TCP' -or [string]$port.Protocol -eq '6') -and [string]$port.LocalPort -eq '300' -and ([string]$address.RemoteAddress -match 'LocalSubnet') -and ([string]$item.Profile -match 'Private')){$ok=$true}
 }
 if(-not $ok){Write-Host 'MISMATCH: firewall rule does not match TCP 300 Private LocalSubnet';exit 1}
 Write-Host 'OK: HTTP.sys reservation and LAN firewall rule found.'
 exit 0
} catch {
 Write-Host ('LAN check failed: '+$_.Exception.Message)
 exit 1
}
