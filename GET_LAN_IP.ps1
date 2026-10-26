$ErrorActionPreference='Stop'
# Prefer the physical adapter carrying the default IPv4 route; ignore virtual/VPN adapters when possible.
$routes=@(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric,InterfaceMetric)
foreach($route in $routes){
 $ips=@(Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\\.|169\\.254\\.)' -and $_.AddressState -eq 'Preferred' })
 foreach($ip in $ips){
  $adapter=Get-NetAdapter -InterfaceIndex $ip.InterfaceIndex -ErrorAction SilentlyContinue
  if($adapter -and $adapter.Status -eq 'Up' -and $adapter.InterfaceDescription -notmatch 'Hyper-V|Virtual|VPN|TAP|TUN|WSL|Docker|Loopback|VMware|VirtualBox'){
   Write-Output $ip.IPAddress
   exit 0
  }
 }
}
foreach($route in $routes){
 $ip=Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\\.|169\\.254\\.)' } | Select-Object -First 1
 if($ip){Write-Output $ip.IPAddress;exit 0}
}
Write-Error 'No usable IPv4 LAN address. Check Wi-Fi/Ethernet connection.'
exit 1
