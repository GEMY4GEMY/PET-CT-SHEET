$ErrorActionPreference='Stop'
$log=Join-Path $PSScriptRoot 'Logs'
New-Item -ItemType Directory -Force -Path $log | Out-Null
$out=Join-Path $log 'server-output.log'
$err=Join-Path $log 'server-error.log'
try {
 & (Join-Path $PSScriptRoot 'Server.ps1') *>> $out
} catch {
 ('['+(Get-Date -Format s)+'] '+($_ | Out-String)) | Add-Content -LiteralPath $err -Encoding UTF8
 throw
}
