# 33 - Remove Source User from Office 365 Groups
# Removes the source user from all O365 group memberships and ownerships.
# Verifies the target user is already a member/owner before removing the source.
# Yammer-connected groups are excluded.
#
# Requires: Microsoft.Graph
# Permissions: Group.ReadWrite.All, User.Read.All
# CSV columns: SourceUpn, TargetUpn

# ---- CONFIGURATION ----
$tenantName = "contoso.onmicrosoft.com"
$csvPath    = "C:\Temp\users.csv"
# -----------------------

Connect-MgGraph -TenantId $tenantName -Scopes 'Group.Read.All','Group.ReadWrite.All','User.Read.All'

$csv = Import-Csv -Path $csvPath -Delimiter ","

foreach ($user in $csv) {
    $sourceUpn = $user.SourceUpn
    $targetUpn = $user.TargetUpn

    $sourceUser = Get-MgUser -UserId $sourceUpn -ErrorAction SilentlyContinue
    $targetUser = Get-MgUser -UserId $targetUpn -ErrorAction SilentlyContinue

    if ($sourceUser -and $targetUser) {

        $sourceMember = Get-MgUserMemberOfAsGroup -UserId $sourceUser.Id -All -Property * |
            Where-Object { $_.GroupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" }

        $targetMember = Get-MgUserMemberOfAsGroup -UserId $targetUser.Id -All -Property * |
            Where-Object { $_.GroupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" }

        $targetOwner = Get-MgUserOwnedObject -UserId $targetUser.Id -All -Property * |
            Where-Object { $_.AdditionalProperties.groupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" } |
            Select-Object Id, @{n='MailNickname'; e={$_.AdditionalProperties.mailNickname}}

        # Remove source user from group memberships
        foreach ($group in $sourceMember) {
            if ($targetMember.Id -contains $group.Id) {
                Write-Host "Removing $sourceUpn as Member from $($group.MailNickname)"
                # Comment out the line below for a dry run
                Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $sourceUser.Id
            }
            else {
                Write-Host "Warning: $targetUpn not a member of $($group.MailNickname) — skipping removal of $sourceUpn" -BackgroundColor Red
            }
        }

        $sourceOwner = Get-MgUserOwnedObject -UserId $sourceUser.Id -All -Property * |
            Where-Object { $_.AdditionalProperties.groupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" } |
            Select-Object Id, @{n='MailNickname'; e={$_.AdditionalProperties.mailNickname}}

        # Remove source user from group ownerships
        foreach ($group in $sourceOwner) {
            if ($targetOwner.Id -contains $group.Id) {
                Write-Host "Removing $sourceUpn as Owner from $($group.MailNickname)"
                # Comment out the line below for a dry run
                Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $sourceUser.Id
            }
            else {
                Write-Host "Warning: $targetUpn not an owner of $($group.MailNickname) — skipping removal of $sourceUpn" -BackgroundColor Red
            }
        }
    }
}
