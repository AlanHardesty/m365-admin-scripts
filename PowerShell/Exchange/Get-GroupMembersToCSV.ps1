# Get-GroupMembersToCSV.ps1
# Exports all user members of an Entra ID / Microsoft 365 group to CSV.
#
# Requires: Microsoft.Graph
# Permissions: Group.Read.All, GroupMember.Read.All, User.Read.All, Directory.Read.All

# ---- CONFIGURATION ----
$groupName = "Your Group Name Here"
$outputCsv = "C:\Temp\Exchange\GroupMembers.csv"
# -----------------------

Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement

Connect-MgGraph -Scopes "Group.Read.All","GroupMember.Read.All","User.Read.All","Directory.Read.All"

$group = Get-MgGroup -Filter "displayName eq '$groupName'"

if (-not $group) {
    Write-Error "Group '$groupName' not found."
    Disconnect-MgGraph
    exit
}

$members = Get-MgGroupMember -GroupId $group.Id -All

$memberDetails = @()
foreach ($member in $members) {
    if ($member.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user') {
        $memberDetails += [PSCustomObject]@{
            DisplayName       = $member.AdditionalProperties.displayName
            UserPrincipalName = $member.AdditionalProperties.userPrincipalName
            Mail              = $member.AdditionalProperties.mail
            ObjectId          = $member.Id
        }
    }
}

$memberDetails | Format-Table -AutoSize
$memberDetails | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($memberDetails.Count) member(s) to: $outputCsv" -ForegroundColor Green

Disconnect-MgGraph
