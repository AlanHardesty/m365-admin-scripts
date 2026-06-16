# 10 - Inventory SPO Permissions (legacy - non O365 group connected sites)
# Generates a CSV report of SharePoint site permissions for users not in O365 group-connected sites.
# Output is used as input for scripts 12 and 34.
#
# Requires: Microsoft.Online.SharePoint.PowerShell, PnP.PowerShell
# Permissions: SharePoint Administrator

# ---- CONFIGURATION ----
$adminUrl    = "https://contoso-admin.sharepoint.com"
$pnpClientId = "YOUR-PNP-CLIENT-ID"
# -----------------------

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -UseWindowsPowerShell
Import-Module PnP.PowerShell

Connect-SPOService -Url $adminUrl -ModernAuth $true

# Get all SharePoint site collections
$siteCollectionsAll = Get-SPOSite -Limit All
$siteCollectionsAll.count

# Filter out sites connected to a UnifiedGroup or TeamsChannel
$siteCollections = $siteCollectionsAll | Where-Object {
    $_.GroupId          -eq "00000000-0000-0000-0000-000000000000" -and
    $_.RelatedGroupId   -eq "00000000-0000-0000-0000-000000000000" -and
    $_.IsTeamsChannelConnected -ne $true
}

# Filter out system/application site templates
$siteCollections = $siteCollections | Where-Object {
    $_.Template -notin "RedirectSite#0","APPCATALOG#0","EDISC#0","SRCHCEN#0","PWA#0","STS#-1"
}

# Filter to /sites/* and exclude application-owned sites
# Update the -notlike filters below to match your organization's application site URLs
$siteCollections = $siteCollections | Where-Object { $_.Url -like "*/sites/*" }
# Example exclusions:
# $siteCollections = $siteCollections | Where-Object { $_.Url -notlike "*/sites/AppSite1*" }
# $siteCollections = $siteCollections | Where-Object { $_.Url -notlike "*/sites/AppSite2*" }

$siteCollections.count

# Export site list — can be re-imported to skip re-fetching on reruns
$siteCollections | Export-Csv C:\Temp\SPOsiteCollections.csv -Delimiter ";" -Encoding Unicode -NoTypeInformation

# Re-import if already exported recently
# $siteCollections = Import-Csv C:\Temp\SPOsiteCollections.csv -Delimiter ";"

# Connect PnP
$pnpConnection = Connect-PnPOnline -Url $adminUrl -Interactive -ReturnConnection -ClientId $pnpClientId

function Get-PnPSitePermissions {
    param (
        [string]$User,
        [bool]$IncludeSiteCollectionAdmin
    )

    if ($IncludeSiteCollectionAdmin) {
        [array]$siteAdmins = Get-PnPSiteCollectionAdmin |
            Where-Object { $_.IsSiteAdmin -eq $true } |
            Select-Object LoginName, Email, Title,
                @{Name='Permission'; Expression={'siteAdmin'}},
                GroupName
    }

    $siteOwnerGroup   = Get-PnPGroup -AssociatedOwnerGroup
    $siteMemberGroup  = Get-PnPGroup -AssociatedMemberGroup
    $siteVisitorGroup = Get-PnPGroup -AssociatedVisitorGroup

    [array]$siteOwners   = Get-PnPGroupMember -Group $siteOwnerGroup   | Select-Object LoginName, Email, Title, @{Name='Permission'; Expression={'siteOwner'}},   @{Name='GroupName'; Expression={$siteOwnerGroup.LoginName}}
    [array]$siteMembers  = Get-PnPGroupMember -Group $siteMemberGroup  | Select-Object LoginName, Email, Title, @{Name='Permission'; Expression={'siteMember'}},  @{Name='GroupName'; Expression={$siteMemberGroup.LoginName}}
    [array]$siteVisitors = Get-PnPGroupMember -Group $siteVisitorGroup | Select-Object LoginName, Email, Title, @{Name='Permission'; Expression={'siteVisitor'}}, @{Name='GroupName'; Expression={$siteVisitorGroup.LoginName}}

    if ($User) {
        return ($siteAdmins + $siteOwners + $siteMembers + $siteVisitors |
            Where-Object { $_.LoginName -like "*$User" -or $_.Email -eq $User })
    } else {
        return ($siteAdmins + $siteOwners + $siteMembers + $siteVisitors)
    }
}
