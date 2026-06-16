# Get-LitigationHoldStatus.ps1
# Checks litigation hold status and last sign-in date for a list of users.
# Combines Microsoft Graph (sign-in activity) and Exchange Online (hold status).
#
# Requires: Microsoft.Graph, ExchangeOnlineManagement
# Input CSV column: UserPrincipalName

# ---- CONFIGURATION ----
$inputCsv  = "C:\Temp\users.csv"
$outputCsv = "C:\Temp\LitigationHoldStatus.csv"
# -----------------------

Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All"
Connect-ExchangeOnline

$users = Import-Csv -Path $inputCsv -Delimiter ","

$results = foreach ($user in $users) {
    $upn = $user.UserPrincipalName.Trim()

    try {
        $userData = Get-MgUser -Filter "userPrincipalName eq '$upn'" `
            -Property "userPrincipalName","displayName","signInActivity" `
            -ErrorAction Stop

        if ($userData) {
            $litigationHold = "N/A"
            try {
                $mailbox        = Get-Mailbox -Identity $upn -ErrorAction Stop
                $litigationHold = if ($mailbox.LitigationHoldEnabled) { "Yes" } else { "No" }
            }
            catch {}

            [PSCustomObject]@{
                UPN            = $upn
                Name           = $userData.DisplayName
                Status         = "Found"
                LastSignInDate = if ($userData.SignInActivity.LastSignInDateTime) { $userData.SignInActivity.LastSignInDateTime } else { "Never" }
                LitigationHold = $litigationHold
            }
        }
        else {
            [PSCustomObject]@{
                UPN = $upn; Name = "N/A"; Status = "Not Found"
                LastSignInDate = "N/A"; LitigationHold = "N/A"
            }
        }
    }
    catch {
        [PSCustomObject]@{
            UPN = $upn; Name = "N/A"; Status = "Error: $_"
            LastSignInDate = "N/A"; LitigationHold = "N/A"
        }
    }
}

$results | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Exported to: $outputCsv" -ForegroundColor Green
$results | Format-Table -AutoSize
