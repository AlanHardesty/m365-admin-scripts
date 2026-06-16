# 20 - Update Mail Contact External Email Address
# Sets the ExternalEmailAddress on the target mail user to their new address in the target tenant.
#
# Requires: Microsoft.Graph, ExchangeOnlineManagement
# CSV columns: SourceUpn, TargetUpn

# ---- CONFIGURATION ----
$tenantName = "contoso.onmicrosoft.com"
$csvPath    = "C:\Temp\users.csv"
# -----------------------

$csv = Import-Csv $csvPath -Delimiter ","
Write-Host "CSV contains $($csv.Count) users"

Connect-MgGraph -TenantId $tenantName
Connect-ExchangeOnline

foreach ($user in $csv) {
    $targetUpn  = $user.TargetUpn
    $targetUser = Get-MgUser -UserId $targetUpn -Property Mail,ProxyAddresses -ErrorAction SilentlyContinue
    $newEmail   = $targetUser.Mail

    Write-Host "$($user.SourceUpn) will get ExternalEmail: $newEmail"

    try {
        Set-MailUser -Identity $targetUpn -ExternalEmailAddress $newEmail
    }
    catch {
        Write-Host "Could not set ExternalEmailAddress for $targetUpn" -ForegroundColor Red
    }
}
