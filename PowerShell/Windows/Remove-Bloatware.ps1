# Remove-Bloatware.ps1
# Removes common pre-installed Windows 10/11 bloatware for all users.
# Edit the $appsToRemove list as needed for your environment.
#
# Run as Administrator.

$appsToRemove = @(
    "*CandyCrush*",
    "*Facebook*",
    "*Spotify*",
    "*Xbox*",
    "*ZuneMusic*",
    "*BingWeather*",
    "*MicrosoftSolitaireCollection*",
    "*LinkedIn*",
    "*Twitter*",
    "*SkypeApp*",
    "*GetHelp*",
    "*Disney*",
    "*Clipchamp*",
    "*DevHome*"
)

foreach ($app in $appsToRemove) {
    Get-AppxPackage       -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

Write-Host "Bloatware removal complete. Restart Explorer or reboot for changes to take effect." -ForegroundColor Green
