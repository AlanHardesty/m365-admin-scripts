# Get-MFAStatus.ps1
# Checks MFA (authentication method) registration status for a list of users.
# A user with zero registered authentication methods is treated as MFA-disabled.
#
# Requires: Microsoft.Graph
# Input CSV column: UserPrincipalName

# ---- CONFIGURATION ----
$usersFilePath    = "C:\Temp\Users.csv"
$mfaStatusFilePath = "C:\Temp\MFAStatus.csv"
$csvDelimiter     = ","
# -----------------------

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Identity.DirectoryManagement

Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All"

$users = Import-Csv -Path $usersFilePath -Delimiter $csvDelimiter

$results = @()

foreach ($user in $users) {
    $methods = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName -ErrorAction SilentlyContinue

    $results += [PSCustomObject]@{
        UserPrincipalName = $user.UserPrincipalName
        MFAStatus         = if ($methods.Count -gt 0) { "Enabled" } else { "Disabled" }
        MethodCount       = $methods.Count
    }
}

$results | Export-Csv -Path $mfaStatusFilePath -NoTypeInformation -Encoding UTF8
Write-Host "MFA status report exported to: $mfaStatusFilePath" -ForegroundColor Green
$results | Format-Table -AutoSize
