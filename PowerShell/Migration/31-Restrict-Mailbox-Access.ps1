# 31 - Restrict Mailbox Client Access
# Disables all client access protocols on source mailboxes after migration.
# Excludes accounts listed in an ApplicationUsers exclusion CSV.
# Includes a restore section (commented out) to re-enable access if needed.
#
# Requires: ExchangeOnlineManagement
# CSV columns: SourceUpn

# ---- CONFIGURATION ----
$csvPath         = "C:\Temp\users.csv"
$excludeCsvPath  = "C:\Temp\ApplicationUsers.csv"  # Accounts to exclude from restriction
# -----------------------

Connect-ExchangeOnline

$csv = Import-Csv $csvPath -Delimiter ","
Write-Host "CSV contains $($csv.Count) users"

$excludeUsers = Import-Csv $excludeCsvPath -Delimiter ","
$csv = $csv | Where-Object { $_.SourceUpn -notin $excludeUsers.SourceUpn }
Write-Host "Excluding $($excludeUsers.Count) application accounts. Processing $($csv.Count) accounts."

# ---- Disable all client access ----
foreach ($user in $csv) {
    Get-Recipient -Identity $user.SourceUpn | Set-CASMailbox `
        -OWAEnabled $false -OWAforDevicesEnabled $false `
        -PopEnabled $false -ActiveSyncEnabled $false `
        -EwsAllowEntourage $false -EwsAllowOutlook $false -EwsAllowMacOutlook $false `
        -EwsEnabled $false -ImapEnabled $false `
        -MacOutlookEnabled $false -UniversalOutlookEnabled $false `
        -MAPIEnabled $false -OutlookMobileEnabled $false
}

# ---- Verify settings ----
foreach ($user in $csv) {
    Write-Host $user.SourceUpn
    Get-Recipient -Identity $user.SourceUpn | Get-CASMailbox |
        Select-Object OWAEnabled, OWAforDevicesEnabled, PopEnabled, ActiveSyncEnabled,
            EwsAllowEntourage, EwsAllowOutlook, EwsAllowMacOutlook, EwsEnabled,
            ImapEnabled, MacOutlookEnabled, UniversalOutlookEnabled, MAPIEnabled, OutlookMobileEnabled
}

# ---- Restore access (run separately if rollback needed) ----
<#
foreach ($user in $csv) {
    Get-Recipient -Identity $user.SourceUpn | Set-CASMailbox `
        -OWAEnabled $true -OWAforDevicesEnabled $true `
        -PopEnabled $true -ActiveSyncEnabled $true `
        -EwsAllowEntourage $true -EwsAllowOutlook $true -EwsAllowMacOutlook $true `
        -EwsEnabled $true -ImapEnabled $true `
        -MacOutlookEnabled $true -UniversalOutlookEnabled $true `
        -MAPIEnabled $true -OutlookMobileEnabled $true
}
#>
