$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$log=Join-Path $root 'Logs'
New-Item -ItemType Directory -Force -Path $log | Out-Null
try { & (Join-Path $root 'Server.ps1') *>> (Join-Path $log 'server-error.log') }
catch { ($_ | Out-String) | Out-File (Join-Path $log 'server-error.log') -Append -Encoding UTF8 }