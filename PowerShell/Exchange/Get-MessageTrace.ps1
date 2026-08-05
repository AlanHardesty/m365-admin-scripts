# Get-MessageTrace.ps1
# Runs a message trace for one or more mailboxes and exports results to CSV.
# Automatically uses Get-MessageTraceV2 (supports up to 90 days) when available,
# falls back to Get-MessageTrace (10-day limit) otherwise.
#
# Requires: ExchangeOnlineManagement v3.7.0+
# Input CSV column: MbxAddress

# ---- CONFIGURATION ----
$InputCsv  = "C:\Temp\Exchange\traceaddress.csv"   # One address per row, header: MbxAddress
$OutputCsv = "C:\Temp\Exchange\MessageTrace_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$DaysBack  = 10   # Get-MessageTrace supports ~10 days; Get-MessageTraceV2 supports up to 90
# -----------------------

Connect-ExchangeOnline

$Mailboxes = Import-Csv -Path $InputCsv -Delimiter "," | Select-Object -ExpandProperty MbxAddress
$StartDate = (Get-Date).AddDays(-$DaysBack)
$EndDate   = Get-Date

Write-Host "Tracing messages for $($Mailboxes.Count) mailbox(es)..." -ForegroundColor Green

if (Get-Command Get-MessageTraceV2 -ErrorAction SilentlyContinue) {
    $Traces = Get-MessageTraceV2 -RecipientAddress $Mailboxes `
                                 -StartDate $StartDate `
                                 -EndDate $EndDate `
                                 -ResultSize 5000
}
else {
    $Traces = Get-MessageTrace -RecipientAddress $Mailboxes `
                               -StartDate $StartDate `
                               -EndDate $EndDate
}

$Traces | Select-Object `
    Received, SenderAddress, RecipientAddress, Subject, Status,
    Size, MessageId, MessageTraceId, FromIP, ToIP |
    Sort-Object Received -Descending |
    Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Done. Results exported to: $OutputCsv" -ForegroundColor Green
