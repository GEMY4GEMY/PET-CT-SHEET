$ErrorActionPreference='Stop'
$logs=Join-Path $PSScriptRoot 'Logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$log=Join-Path $logs 'lan-setup.log'
try {
 $id=[Security.Principal.WindowsIdentity]::GetCurrent()
 $admin=(New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 if(-not $admin){throw 'Administrator approval required for Windows Firewall changes'}
 $name='PET CT SHEET LAN TCP 500'
 $old=Get-NetFirewallRule -DisplayName 'PET CT SHEET LAN TCP 300' -ErrorAction SilentlyContinue
 if($old){$old | Remove-NetFirewallRule -ErrorAction SilentlyContinue}
 $existing=Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue
 if($existing){$existing | Remove-NetFirewallRule -ErrorAction Stop}
 New-NetFirewallRule -DisplayName $name -Direction Inbound -Protocol TCP -LocalPort 500 -RemoteAddress LocalSubnet -Profile Private -Action Allow -Enabled True -ErrorAction Stop | Out-Null
 $rule=Get-NetFirewallRule -DisplayName $name -ErrorAction Stop
 if(-not $rule){throw 'Firewall rule was not created'}
 ('SUCCESS '+(Get-Date -Format s)+' Private LocalSubnet TCP 500') | Add-Content -LiteralPath $log
 Write-Host 'Firewall ready for devices on the same private LAN, port 500.'
 Write-Host 'No HTTP URL reservation is needed with the new TCP server.'
 exit 0
} catch {
 ('FAILED '+(Get-Date -Format s)+' '+$_.Exception.Message) | Add-Content -LiteralPath $log
 Write-Host ('Firewall setup failed: '+$_.Exception.Message)
 exit 1
}
