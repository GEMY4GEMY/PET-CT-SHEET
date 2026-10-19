$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$startup=[Environment]::GetFolderPath('Startup')
$wsh=New-Object -ComObject WScript.Shell
$link=$wsh.CreateShortcut((Join-Path $startup 'NuclearScan Server.lnk'))
$link.TargetPath="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$link.Arguments='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $root 'Watchdog.ps1')+'"'
$link.WorkingDirectory=$root
$link.Save()
$task='NuclearScan Daily Backup'
$exe="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$args='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $root 'DAILY_BACKUP.ps1')+'"'
$action=New-ScheduledTaskAction -Execute $exe -Argument $args -WorkingDirectory $root
$triggers=@((New-ScheduledTaskTrigger -Daily -At '18:00'),(New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME))
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
try {Register-ScheduledTask -TaskName $task -Action $action -Trigger $triggers -Settings $settings -Description 'Daily backup for NuclearScan bookings' -Force | Out-Null;Write-Host 'Autostart and daily backup task enabled.'}
catch {Write-Warning "Autostart shortcut enabled; scheduled backup registration failed: $($_.Exception.Message). Use DAILY_BACKUP.bat manually until resolved."}