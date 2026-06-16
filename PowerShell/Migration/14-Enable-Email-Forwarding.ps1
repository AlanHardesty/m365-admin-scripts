# 14 - Enable Email Forwarding and Add Users to Forwarding Group
# Adds source users to a distribution group that grants permission to forward email.
#
# Requires: ExchangeOnlineManagement
# CSV columns: SourceUpn

# ---- CONFIGURATION ----
$csvPath   = "C:\Temp\users.csv"
$GroupName = "ExchangeOnline Allow Email Forwarding"   # Update to match your group name
# -----------------------

Connect-ExchangeOnline

$csv = Import-Csv -Path $csvPath

foreach ($user in $csv) {
    try {
        Add-DistributionGroupMember -Identity $GroupName -Member $user.SourceUpn -Confirm:$false
        Write-Host "Added $($user.SourceUpn) to $GroupName" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not add $($user.SourceUpn) to $GroupName" -ForegroundColor Red
    }
}
