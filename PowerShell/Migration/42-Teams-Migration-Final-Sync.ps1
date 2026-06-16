# 42 - Teams Migration Final Sync
# Part 1: Demotes all Team owners to members (except designated service accounts).
# Part 2: Sets associated SharePoint sites to ReadOnly, disables offline sync,
#         removes from search index, and disables external sharing.
#
# Requires: MicrosoftTeams, Microsoft.Online.SharePoint.PowerShell, PnP.PowerShell
# Permissions: Teams Administrator, SharePoint Administrator
# CSV format: single column with header "GroupID"

# ---- CONFIGURATION ----
$adminUrl    = "https://contoso-admin.sharepoint.com"
$pnpClientId = "YOUR-PNP-CLIENT-ID"
$tenantName  = "contoso.onmicrosoft.com"
$myAdminName = "admin@contoso.onmicrosoft.com"   # Admin account — temporarily added as site collection admin where needed
$csvPath     = "C:\Temp\teams.csv"
$reportPath  = "C:\Temp\teams_report.csv"

# Service accounts that should NOT be demoted from owner
$skipDemotionAccounts = @(
    "svc_MigrationTool@contoso.onmicrosoft.com"
)
# -----------------------

Import-Module MicrosoftTeams
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Import-Module PnP.PowerShell

$groupIDs = Import-Csv -Path $csvPath -Delimiter "," | Select-Object @{Name='GroupID'; Expression={$_.'GroupID'}}
Write-Host "GroupIDs read from file: $($groupIDs.Count)"

Connect-MicrosoftTeams
Connect-SPOService -Url $adminUrl
$pnpConnection = Connect-PnPOnline -Url $adminUrl -ReturnConnection -ClientId $pnpClientId -Interactive -LaunchBrowser -Tenant $tenantName

# =================================================================
# Part 1 — Demote Team Owners to Members
# =================================================================

$report = @()

foreach ($group in $groupIDs) {
    $GroupID = $group.GroupID
    $Team    = Get-Team -GroupId $GroupID
    Write-Host $Team.DisplayName -ForegroundColor Cyan

    $owners = Get-TeamUser -GroupId $GroupID -Role Owner

    foreach ($owner in $owners) {
        if ($owner.User -in $skipDemotionAccounts) {
            Write-Host "  Skipping demotion for $($owner.User)"
            continue
        }
        Add-TeamUser    -GroupId $GroupID -User $owner.UserId -Role Member
        Remove-TeamUser -GroupId $GroupID -User $owner.UserId -Role Owner
        Write-Host "  Demoted $($owner.User) from Owner to Member"
    }

    $report += [PSCustomObject]@{
        GroupID    = $GroupID
        TeamName   = $Team.DisplayName
        IsArchived = $Team.Archived
    }

    if ($Team.Archived) {
        Write-Host "  Status: Archived" -ForegroundColor Green
    } else {
        Write-Host "  Status: Active" -ForegroundColor Yellow
    }
}

$report | Format-Table -AutoSize
$report | Export-Csv -Path $reportPath -NoTypeInformation

# =================================================================
# Part 2 — Set SharePoint Sites to ReadOnly
# =================================================================

$pnpConnection = Connect-PnPOnline -Url $adminUrl -ReturnConnection -ClientId $pnpClientId -Interactive -LaunchBrowser -Tenant $tenantName
$pnpSites = Get-PnPTenantSite -Connection $pnpConnection

function Test-PnPSiteAccess {
    try {
        Connect-PnPOnline -Url $siteUrl -Connection $pnpConnection -ClientId $pnpClientId -Interactive -LaunchBrowser -Tenant $tenantName
        Get-PnPSite
        return $true
    }
    catch {
        Write-Host " Get-PnPSite failed: $($_.Exception.Message)"
        return $false
    }
}

function Set-SiteProperties {
    param ([string]$SiteURL)

    Connect-PnPOnline -Url $SiteURL -Connection $pnpConnection -ClientId $pnpClientId -Interactive -LaunchBrowser -Tenant $tenantName

    $web  = Get-PnPWeb -Includes ExcludeFromOfflineClient, NoCrawl
    $site = Get-SPOSite -Identity $SiteURL

    if ($SiteURL -ne $site.Url -or $SiteURL -ne $web.Url) {
        Write-Host "Failed to connect to $SiteURL" -ForegroundColor Red
        return
    }

    Write-Host "Site: ""$($site.Title)"" — $($site.Url)" -ForegroundColor Blue

    if ($web.ExcludeFromOfflineClient -ne "True" -or $web.NoCrawl -ne "True" -or $site.SharingCapability -ne "Disabled") {

        if ($site.LockState -ne "UnLock") { Set-SPOSite -Identity $SiteURL -LockState UnLock }

        if ($web.ExcludeFromOfflineClient -ne "True") {
            Write-Host " -> Disable offline sync"
            $web.ExcludeFromOfflineClient = $true
            $web.Update()
            Invoke-PnPQuery
        }

        if ($web.NoCrawl -ne "True") {
            if ($site.DenyAddAndCustomizePages -eq "Enabled") {
                Set-SPOSite $SiteURL -DenyAddAndCustomizePages 0
            }
            Write-Host " -> Disable crawl (remove from search index)"
            $web = Get-PnPWeb
            $web.NoCrawl = $true
            $web.Update()
            Invoke-PnPQuery
            if ($site.DenyAddAndCustomizePages -eq "Enabled") {
                Set-SPOSite $SiteURL -DenyAddAndCustomizePages 1
            }
        }

        if ($site.SharingCapability -ne "Disabled") {
            Write-Host " -> Disable external sharing"
            Set-SPOSite $SiteURL -SharingCapability Disabled
        }

        Set-SPOSite -Identity $SiteURL -LockState ReadOnly
    }
    elseif ($site.LockState -ne "ReadOnly") {
        Set-SPOSite -Identity $SiteURL -LockState ReadOnly
    }

    # Verify
    $web  = Get-PnPWeb -Includes ExcludeFromOfflineClient, NoCrawl
    $site = Get-SPOSite -Identity $SiteURL

    if ($site.LockState -eq "ReadOnly" -and $web.NoCrawl -eq "True" -and
        $web.ExcludeFromOfflineClient -eq "True" -and $site.SharingCapability -eq "Disabled") {
        Write-Host " Site correctly configured:" -ForegroundColor Green -NoNewline
        Write-Host " $($site.Url)"
    }
    else {
        Write-Host "Site update failed: $($site.Url)" -ForegroundColor Red
        Write-Host " LockState: $($site.LockState)"
        Write-Host " ExcludeFromOfflineClient: $($web.ExcludeFromOfflineClient)"
        Write-Host " NoCrawl: $($web.NoCrawl)"
        Write-Host " ExternalSharing: $($site.SharingCapability)"
    }
}

foreach ($group in $groupIDs) {
    $GroupID = $group.GroupID
    $Team    = $pnpSites | Where-Object { $_.GroupId -eq $GroupID }
    $siteUrl = $Team.Url
    Write-Host "Team: $($Team.Title) $GroupID $siteUrl"

    if (-not $siteUrl) {
        Write-Host "No SharePoint site found for GroupID: $GroupID"
        continue
    }

    $teamStatus = Get-Team -GroupId $GroupID

    if ($teamStatus.Archived) {
        # Public archived sites require temporary admin elevation to modify properties
        if ($teamStatus.Visibility -eq "Public") {
            $spoSite = Get-SPOSite -Identity $siteUrl
            if ($spoSite.LockState -eq "ReadOnly") { Set-SPOSite -Identity $siteUrl -LockState UnLock }
            Set-SPOUser -Site $siteUrl -LoginName $myAdminName -IsSiteCollectionAdmin $true
            if ($spoSite.LockState -eq "ReadOnly") { Set-SPOSite -Identity $siteUrl -LockState ReadOnly }
            Start-Sleep -Seconds 2
        }

        if (-not (Test-PnPSiteAccess)) {
            Write-Host " Unauthorized — adding $myAdminName as Site Collection Admin" -ForegroundColor DarkGray
            $spoSite = Get-SPOSite -Identity $siteUrl
            if ($spoSite.LockState -eq "ReadOnly") { Set-SPOSite -Identity $siteUrl -LockState UnLock }
            Set-SPOUser -Site $siteUrl -LoginName $myAdminName -IsSiteCollectionAdmin $true
            if ($spoSite.LockState -eq "ReadOnly") { Set-SPOSite -Identity $siteUrl -LockState ReadOnly }
            Start-Sleep -Seconds 2
        }

        if (Test-PnPSiteAccess) {
            Set-SiteProperties $siteUrl
        }
        else {
            Write-Host " Unauthorized: $siteUrl" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "-----------------------------------------------------"
    Write-Host ""
}
