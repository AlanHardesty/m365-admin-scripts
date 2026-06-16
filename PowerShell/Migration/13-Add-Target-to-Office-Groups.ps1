# 13 - Add Target User to Office 365 Groups
# Mirrors the source user's O365 group memberships (member and owner) onto the target account.
# Includes a post-run validation section that compares member/owner counts between accounts.
# Yammer-connected groups are excluded.
#
# Requires: Microsoft.Graph
# Permissions: Group.ReadWrite.All, User.Read.All, Directory.Read.All
# CSV columns: SourceUpn, TargetUpn

# ---- CONFIGURATION ----
$tenantName = "contoso.onmicrosoft.com"
$csvPath    = "C:\Temp\users.csv"
# -----------------------

Connect-MgGraph -TenantId $tenantName -Scopes 'Group.Read.All','Group.ReadWrite.All','User.Read.All','Directory.Read.All'

$csv = Import-Csv -Path $csvPath -Delimiter ";"

# ---- Add target user to groups ----
foreach ($user in $csv) {
    $sourceUpn = $user.SourceUpn
    $targetUpn = $user.TargetUpn

    $sourceUser = Get-MgUser -UserId $sourceUpn -ErrorAction SilentlyContinue
    $targetUser = Get-MgUser -UserId $targetUpn -ErrorAction SilentlyContinue

    if ($sourceUser -and $targetUser) {

        # Mirror group memberships
        $groupMember = Get-MgUserMemberOfAsGroup -UserId $sourceUser.Id -All -Property * |
            Where-Object { $_.GroupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" }

        foreach ($group in $groupMember) {
            Write-Host "Adding $($targetUser.DisplayName) to group $($group.MailNickname) as MEMBER"
            # Comment out the line below for a dry run
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $targetUser.Id
        }

        # Mirror group ownerships
        $groupOwner = Get-MgUserOwnedObject -UserId $sourceUser.Id -All -Property * |
            Where-Object { $_.AdditionalProperties.groupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" } |
            Select-Object Id,
                @{n='DisplayName'; e={$_.AdditionalProperties.displayName}},
                @{n='MailNickname'; e={$_.AdditionalProperties.mailNickname}}

        foreach ($group in $groupOwner) {
            Write-Host "Adding $($targetUser.DisplayName) to group $($group.MailNickname) as OWNER" -ForegroundColor DarkYellow
            # Comment out the line below for a dry run
            New-MgGroupOwner -GroupId $group.Id -DirectoryObjectId $targetUser.Id
        }
    }
    else {
        Write-Host "User not found: $sourceUpn or $targetUpn" -BackgroundColor Red
    }
}

# ---- Validation: compare group counts between source and target ----
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

        if ($sourceMember.Count -eq $targetMember.Count) {
            Write-Host "$sourceUpn / $targetUpn member count match ($($sourceMember.Count))" -ForegroundColor DarkGreen
        } else {
            Write-Host "$sourceUpn / $targetUpn member count mismatch ($($sourceMember.Count)/$($targetMember.Count)) Diff: " -NoNewline
            Write-Host ($sourceMember.Count - $targetMember.Count) -BackgroundColor Red -NoNewline
            Write-Host " "
        }

        $sourceOwner = Get-MgUserOwnedObject -UserId $sourceUser.Id -All -Property * |
            Where-Object { $_.AdditionalProperties.groupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" }
        $targetOwner = Get-MgUserOwnedObject -UserId $targetUser.Id -All -Property * |
            Where-Object { $_.AdditionalProperties.groupTypes -eq "Unified" -and $_.AdditionalProperties.creationOptions -ne "YammerProvisioning" }

        if ($sourceOwner.Count -eq $targetOwner.Count) {
            Write-Host "$sourceUpn / $targetUpn owner count match ($($sourceOwner.Count))" -ForegroundColor DarkGreen
        } else {
            Write-Host "$sourceUpn / $targetUpn owner count mismatch ($($sourceOwner.Count)/$($targetOwner.Count)) Diff: " -NoNewline
            Write-Host ($sourceOwner.Count - $targetOwner.Count) -BackgroundColor Red -NoNewline
            Write-Host " "
        }
    }
    else {
        if (-not $sourceUser -and $targetUser)  { Write-Host "$sourceUpn not found in Entra ID" }
        if ($sourceUser -and -not $targetUser)  { Write-Host "$targetUpn not found in Entra ID" }
        if (-not $sourceUser -and -not $targetUser) { Write-Host "$sourceUpn and $targetUpn not found in Entra ID" }
    }
}
