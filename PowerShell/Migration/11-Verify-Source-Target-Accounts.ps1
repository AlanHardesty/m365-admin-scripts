# 11 - Verify Source and Target Accounts Exist
# Checks that both the source tenant user and target/guest user exist in Entra ID.
# Run this before starting migration steps to catch missing accounts early.
#
# Requires: Microsoft.Graph
# CSV columns: SourceUpn, TargetUpn

# ---- CONFIGURATION ----
$tenantName = "contoso.onmicrosoft.com"
$csvPath    = "C:\Temp\users.csv"
# -----------------------

$CsvUsers = Import-Csv $csvPath -Delimiter ","

Connect-MgGraph -TenantId $tenantName -Scopes "User.Read.All"

foreach ($user in $CsvUsers) {
    $sourceUpn = $user.SourceUpn
    $targetUpn = $user.TargetUpn

    $sourceExists = Get-MgUser -UserId $sourceUpn -ErrorAction SilentlyContinue
    $targetExists = Get-MgUser -UserId $targetUpn -ErrorAction SilentlyContinue

    if ($sourceExists -and $targetExists) {
        # Both accounts exist — no output needed unless you want a confirmation line
    }
    elseif ($sourceExists -and -not $targetExists) {
        Write-Host "Target account not found: " -NoNewline -BackgroundColor Red
        Write-Host " $sourceUpn" -NoNewline -ForegroundColor Green
        Write-Host " / $targetUpn" -ForegroundColor Red
    }
    elseif (-not $sourceExists -and $targetExists) {
        Write-Host "Source account not found: " -NoNewline -BackgroundColor Red
        Write-Host " $sourceUpn" -NoNewline -ForegroundColor Red
        Write-Host " / $targetUpn" -ForegroundColor Green
    }
    else {
        Write-Host "Neither account found: " -NoNewline -BackgroundColor Red
        Write-Host " $sourceUpn" -NoNewline -ForegroundColor Red
        Write-Host " / $targetUpn" -ForegroundColor Red
    }
}
