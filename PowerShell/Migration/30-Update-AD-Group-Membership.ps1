# 30 - Update Active Directory Group Membership
# Removes source users from the MTO (migration target) AD group and adds them
# to the migrated users group so they fall under the correct Conditional Access policies.
#
# Requires: ActiveDirectory (RSAT)
# CSV columns: SourceUpn

# ---- CONFIGURATION ----
$csvPath         = "C:\Temp\users.csv"
$mtoGroupName    = "Org_MTO_Users"       # Group containing users pending migration
$migratedGroupName = "Org_Migrated_Users" # Group for completed migrations
# -----------------------

Import-Module ActiveDirectory

$csv = Import-Csv $csvPath -Delimiter ";"
Write-Host "CSV contains $($csv.Count) users"

$mtoGroup      = Get-ADGroup $mtoGroupName
$mtoUsers      = Get-ADGroupMember $mtoGroup.ObjectGUID | Get-ADUser
Write-Host "MTO group contains $($mtoUsers.Count) users"

$migratedGroup = Get-ADGroup $migratedGroupName

# Identify users in the MTO group that are in this migration batch
$toRemove = $mtoUsers | Where-Object { $_.UserPrincipalName -in $csv.SourceUpn }
Write-Host "Users to remove from MTO group: $($toRemove.Count)"

# ---- Remove from MTO group ----
$removed = 0
foreach ($user in $toRemove) {
    try {
        Remove-ADGroupMember -Identity $mtoGroup.ObjectGUID -Members $user.ObjectGUID -Confirm:$false
        $removed++
    }
    catch {
        Write-Host "Could not remove $($user.UserPrincipalName) from $mtoGroupName"
    }
}
Write-Host "Removed from MTO group: $removed/$($toRemove.Count)"

# ---- Add to migrated users group ----
$added = 0
foreach ($user in $csv) {
    try {
        $upn = $user.SourceUpn
        $adUser = Get-ADUser -Filter { UserPrincipalName -eq $upn }
        Add-ADGroupMember -Identity $migratedGroup.ObjectGUID -Members $adUser.ObjectGUID
        $added++
    }
    catch {
        Write-Host "Could not add $($user.SourceUpn) to $migratedGroupName"
    }
}
Write-Host "Added to migrated group: $added/$($csv.Count)"
