# 15 - Add Target User to Teams Private Channels
# Scans all Teams for private channels where the source user is a member or owner,
# then adds the target/guest user to the same channels with the same role.
# Produces an intermediate CSV report before making changes.
#
# Requires: Microsoft.Graph, MicrosoftTeams
# Permissions: Teams Administrator, Global Reader
# CSV columns: SourceUpn, TargetUpn

# ---- CONFIGURATION ----
$tenantName  = "contoso.onmicrosoft.com"
$csvPath     = "C:\Temp\users.csv"
$reportPath  = "C:\Temp\TeamsPrivateChannel_Report.csv"

# Domain suffix used to identify target/guest accounts in Entra ID
# Format: targetdomain.com#EXT#@contoso.onmicrosoft.com
$targetDomainSuffix = "targetdomain.com#EXT#@contoso.onmicrosoft.com"
# -----------------------

$CsvUsers = Import-Csv $csvPath -Delimiter ","
Write-Host "$($CsvUsers.Count) users read from CSV"

Connect-MgGraph -TenantId $tenantName
Connect-MicrosoftTeams -TenantId $tenantName

# Pre-load all target/guest users from Entra ID to resolve object IDs
$targetUsers = Get-MgUser `
    -Filter "endsWith(userPrincipalName, '$targetDomainSuffix')" `
    -ConsistencyLevel Eventual -CountVariable count -All

$AllTeams = Get-Team
Write-Host "Teams found: $($AllTeams.Count)"

$report = [System.Collections.Generic.List[Object]]::new()

foreach ($team in $AllTeams) {
    Write-Host "$($AllTeams.GroupId.IndexOf($team.GroupId)+1)/$($AllTeams.Count) Team: $($team.DisplayName)" -ForegroundColor Cyan

    $channels = Get-TeamChannel -GroupId $team.GroupId | Where-Object { $_.MembershipType -eq "Private" }

    foreach ($channel in $channels) {
        Write-Host "  - $($channel.DisplayName)" -ForegroundColor DarkYellow

        $members = Get-TeamChannelUser -GroupId $team.GroupId -DisplayName $channel.DisplayName

        foreach ($member in $members) {
            $index = $CsvUsers.SourceUpn.ToLower().IndexOf($member.User.ToLower())

            if ($index -ne -1) {
                $targetUpn  = $CsvUsers[$index].TargetUpn
                $targetIndex = $targetUsers.UserPrincipalName.ToLower().IndexOf($targetUpn.ToLower())

                if ($targetIndex -ne -1) {
                    $report.Add([PSCustomObject][Ordered]@{
                        TeamId             = $team.GroupId
                        TeamDisplayName    = $team.DisplayName
                        ChannelId          = $channel.Id
                        ChannelDisplayName = $channel.DisplayName
                        ChannelUserId      = $member.UserId
                        ChannelUser        = $member.User
                        ChannelUserRole    = $member.Role
                        ChannelTargetUser  = $targetUpn
                        ChannelTargetUserId = $targetUsers[$targetIndex].Id
                    })
                    Write-Host "     $($member.User) / $($member.Role) / $targetUpn"
                }
                else {
                    Write-Host " !- Could not find target user $targetUpn in Entra ID" -ForegroundColor Red
                }
            }
        }
    }
}

$report | Export-Csv $reportPath -Delimiter ";" -NoTypeInformation -Encoding Unicode
Write-Host "Report exported to $reportPath"

# ---- Add target users to private channels ----
foreach ($item in $report) {
    Write-Host "Adding $($item.ChannelTargetUser) as $($item.ChannelUserRole) to $($item.TeamDisplayName)/$($item.ChannelDisplayName)"

    try {
        if ($item.ChannelUserRole -eq "Owner") {
            # User must already be a team member (added in script 13) before being made an owner
            Add-TeamChannelUser -GroupId $item.TeamId -DisplayName $item.ChannelDisplayName -User $item.ChannelTargetUserId -Role $item.ChannelUserRole
        }
        else {
            Add-TeamChannelUser -GroupId $item.TeamId -DisplayName $item.ChannelDisplayName -User $item.ChannelTargetUserId
        }
    }
    catch {
        $msg = if ($_.Exception.Message -match "Message:\s*(.+)") { $Matches[1] } else { $_.Exception.Message }
        Write-Host " !- Error: $($item.ChannelTargetUser) :: $msg" -ForegroundColor Red
        # "User is not found in the team." = user not yet a team member (run script 13 first)
        # "Could not find member." = user not in team when adding as Member
    }
}

# ---- Verify additions ----
foreach ($item in $report) {
    $members = Get-TeamChannelUser -GroupId $item.TeamId -DisplayName $item.ChannelDisplayName
    if ($members.UserId.IndexOf($item.ChannelTargetUserId) -eq -1) {
        Write-Host "!- Verification failed: $($item.ChannelTargetUser) not in $($item.TeamDisplayName)/$($item.ChannelDisplayName)" -ForegroundColor Red
    }
    else {
        Write-Host " $($item.ChannelTargetUser) confirmed in $($item.TeamDisplayName)/$($item.ChannelDisplayName)" -ForegroundColor Green
    }
}
