# 41 - Teams Migration Preparation
# Disables private channel creation on specified Teams to prepare for migration.
# Input is a CSV containing one GroupID per row.
#
# Requires: MicrosoftTeams
# CSV format: single column with header "GroupID"

# ---- CONFIGURATION ----
$csvPath = "C:\Temp\teams.csv"
# -----------------------

Import-Module MicrosoftTeams

Connect-MicrosoftTeams

$teamIds = Get-Content -Path $csvPath

foreach ($teamId in $teamIds) {
    Get-Team -GroupId $teamId | Select-Object GroupID, DisplayName, Visibility, AllowCreatePrivateChannels
    Set-Team -GroupId $teamId -AllowCreatePrivateChannels $false
}

Disconnect-MicrosoftTeams
