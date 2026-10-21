$url='http://+:300/'
$res=(& netsh.exe http show urlacl url=$url 2>&1 | Out-String)
if($res -notmatch [regex]::Escape($url) -or $res -notmatch 'S-1-5-32-545'){exit 1}
$rule=Get-NetFirewallRule -DisplayName 'PET CT SHEET LAN TCP 300' -ErrorAction SilentlyContinue
if(!$rule -or $rule.Enabled -ne 'True' -or $rule.Action -ne 'Allow' -or $rule.Profile -notmatch 'Private'){exit 1}
$port=$rule | Get-NetFirewallPortFilter
$address=$rule | Get-NetFirewallAddressFilter
if($port.Protocol -ne 'TCP' -or $port.LocalPort -ne '300' -or $address.RemoteAddress -notcontains 'LocalSubnet'){exit 1}
exit 0
