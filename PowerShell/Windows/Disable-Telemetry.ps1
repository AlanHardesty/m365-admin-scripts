# Disable-Telemetry.ps1
# Reduces Windows telemetry to the minimum configurable level on Windows 10/11 Pro.
# Stops and disables telemetry services, disables scheduled telemetry tasks,
# sets registry policies, and blocks known telemetry endpoints via the hosts file.
#
# Run as Administrator.

# Stop and disable telemetry services
Stop-Service  -Name "DiagTrack"        -Force -ErrorAction SilentlyContinue
Set-Service   -Name "DiagTrack"        -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service  -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
Set-Service   -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue

# Disable telemetry scheduled tasks
Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator"     -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient"                                   -ErrorAction SilentlyContinue

# Set telemetry level to Basic (1 = minimum allowed on Pro edition; Enterprise/EDU can use 0)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"                 -Name "AllowTelemetry" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"  -Name "AllowTelemetry" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"    -Name "ShowedToastAtLevel" -Value 1 -Type DWord -Force

# Block known telemetry hosts via the hosts file
$hostsPath = "$env:windir\System32\drivers\etc\hosts"
Add-Content -Path $hostsPath -Value "`n0.0.0.0 vortex.data.microsoft.com"
Add-Content -Path $hostsPath -Value "0.0.0.0 telecommand.telemetry.microsoft.com"
Add-Content -Path $hostsPath -Value "0.0.0.0 settings-sandbox.data.microsoft.com"

Write-Host "Telemetry minimized. Reboot for full effect." -ForegroundColor Green
