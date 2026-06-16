# 32 - Set OneDrive Lock State to NoAccess
# Looks up the OneDrive URL for each source user and sets it to NoAccess.
# Use script 35 to reverse this (set back to UnLock).
#
# Requires: Microsoft.Online.SharePoint.PowerShell, PnP.PowerShell
# Permissions: SharePoint Administrator
# CSV columns: SourceUpn

# ---- CONFIGURATION ----
$adminUrl        = "https://contoso-admin.sharepoint.com"
$pnpClientId     = "YOUR-PNP-CLIENT-ID"
$csvPath         = "C:\Temp\users.csv"
$excludeCsvPath  = "C:\Temp\ApplicationUsers.csv"
# -----------------------

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -UseWindowsPowerShell
Import-Module PnP.PowerShell

Connect-SPOService -Url $adminUrl
$pnpConnection = Connect-PnPOnline -Url $adminUrl -Interactive -ReturnConnection -ClientId $pnpClientId

$csv = Import-Csv $csvPath -Delimiter ";"
Write-Host "CSV contains $($csv.Count) users"

$excludeUsers = Import-Csv $excludeCsvPath -Delimiter ";"
$csv = $csv | Where-Object { $_.SourceUpn -notin $excludeUsers.SourceUpn }
Write-Host "Excluding $($excludeUsers.Count) application accounts. Processing $($csv.Count) accounts."

foreach ($user in $csv) {
    $onedrive = Get-PnPUserProfileProperty -Account $user.SourceUpn -Connection $pnpConnection
    $status   = Get-SPOSite -Identity $onedrive.PersonalUrl.TrimEnd('/') |
                    Select-Object Owner, Url, LockState

    if ($status.LockState -eq "UnLock") {
        Write-Host "Setting NoAccess for $($status.Owner) — $($status.Url)"
        Set-SPOSite -Identity $status.Url -LockState NoAccess
    }
    elseif ($status.LockState -eq "NoAccess") {
        Write-Host "Already NoAccess: $($status.Owner) — $($status.Url)" -ForegroundColor Yellow
    }
}
