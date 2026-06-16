# Get-MessageTrace-PastMonth-Detailed.ps1
# Traces messages for one or more mailboxes over the past 30 days using Get-MessageTraceV2.
# Handles the 10-day-per-query limit by splitting the range into chunks and supports
# basic pagination if the 5000-result cap is hit within a chunk.
# Exports a summary CSV (one row per message, matching EAC report format).
#
# For full hop-by-hop detail, see the instructions at the bottom of this script.
#
# Requires: ExchangeOnlineManagement v3.7.0+
# Input CSV column: MbxAddress

# ---- CONFIGURATION ----
$InputCsv = "C:\Temp\Exchange\traceaddress.csv"
$DaysBack  = 30   # Max ~90 days; V2 queries are split into 10-day chunks automatically
# -----------------------

Connect-ExchangeOnline

$timestamp        = Get-Date -Format 'yyyyMMdd_HHmmss'
$OutputSummaryCsv = "C:\Temp\Exchange\MessageTrace_Summary_$timestamp.csv"

$Mailboxes = Import-Csv -Path $InputCsv | Select-Object -ExpandProperty MbxAddress

if (-not $Mailboxes -or $Mailboxes.Count -eq 0) {
    Write-Error "No addresses found in column 'MbxAddress' of $InputCsv"
    exit 1
}

$EndDateOverall   = Get-Date
$StartDateOverall = $EndDateOverall.AddDays(-$DaysBack)

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Exchange Online Message Trace V2 - Past $DaysBack Days" -ForegroundColor Green
Write-Host "Mailboxes : $($Mailboxes.Count)" -ForegroundColor White
Write-Host "Period    : $($StartDateOverall.ToString('yyyy-MM-dd HH:mm')) UTC  -->  $($EndDateOverall.ToString('yyyy-MM-dd HH:mm')) UTC" -ForegroundColor White
Write-Host "=======================================================" -ForegroundColor Cyan

$allTraces     = [System.Collections.Generic.List[object]]::new()
$chunkSizeDays = 10
$currentStart  = $StartDateOverall

while ($currentStart -lt $EndDateOverall) {
    $currentEnd = $currentStart.AddDays($chunkSizeDays)
    if ($currentEnd -gt $EndDateOverall) { $currentEnd = $EndDateOverall }

    Write-Host ""
    Write-Host ">>> Chunk: $($currentStart.ToString('yyyy-MM-dd')) to $($currentEnd.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan

    try {
        $chunkResults = Get-MessageTraceV2 -RecipientAddress $Mailboxes `
                                           -StartDate $currentStart `
                                           -EndDate $currentEnd `
                                           -ResultSize 5000

        if ($chunkResults) {
            $allTraces.AddRange([array]$chunkResults)
            Write-Host "    Retrieved: $($chunkResults.Count) message(s)" -ForegroundColor Green
        }
        else {
            Write-Host "    No messages in this chunk." -ForegroundColor DarkGray
        }

        # Pagination if the 5000-result cap was hit
        if ($chunkResults -and $chunkResults.Count -eq 5000) {
            Write-Host "    Hit 5000 limit — paginating..." -ForegroundColor Yellow
            $lastRecipient = ($chunkResults | Select-Object -Last 1).RecipientAddress
            $pageEnd       = ($chunkResults | Select-Object -Last 1).Received
            $pageNum       = 2

            while ($true) {
                Write-Host "    Page $pageNum..." -ForegroundColor DarkYellow
                $moreResults = Get-MessageTraceV2 -RecipientAddress $Mailboxes `
                                                  -StartDate $currentStart `
                                                  -EndDate $pageEnd `
                                                  -StartingRecipientAddress $lastRecipient `
                                                  -ResultSize 5000

                if (-not $moreResults) { break }
                $allTraces.AddRange([array]$moreResults)
                Write-Host "      + $($moreResults.Count) additional" -ForegroundColor Green
                if ($moreResults.Count -lt 5000) { break }

                $lastRecipient = ($moreResults | Select-Object -Last 1).RecipientAddress
                $pageEnd       = ($moreResults | Select-Object -Last 1).Received
                $pageNum++
            }
        }
    }
    catch {
        Write-Warning "Error in chunk $($currentStart.ToShortDateString()) - $($currentEnd.ToShortDateString()): $($_.Exception.Message)"
    }

    $currentStart = $currentEnd
}

Write-Host ""
Write-Host "Total traces collected: $($allTraces.Count)" -ForegroundColor Green

if ($allTraces.Count -eq 0) {
    Write-Host "No messages found." -ForegroundColor Yellow
    exit
}

# Deduplicate boundary overlaps
$uniqueTraces = $allTraces | Sort-Object -Property MessageTraceId -Unique
$dupCount     = $allTraces.Count - $uniqueTraces.Count
if ($dupCount -gt 0) { Write-Host "Removed $dupCount duplicate(s) from chunk boundaries." -ForegroundColor Yellow }
$allTraces = $uniqueTraces

Write-Host "Unique traces to export: $($allTraces.Count)" -ForegroundColor Green

$allTraces | Select-Object `
    Received, SenderAddress, RecipientAddress, Subject, Status,
    Size, MessageId, MessageTraceId, FromIP, ToIP,
    @{Name='Event';     Expression={if ($_.PSObject.Properties.Match('Event').Count -gt 0)     { $_.Event }     else { $null }}},
    @{Name='Direction'; Expression={if ($_.PSObject.Properties.Match('Direction').Count -gt 0) { $_.Direction } else { $null }}} |
    Sort-Object Received -Descending |
    Export-Csv -Path $OutputSummaryCsv -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Summary CSV exported to: $OutputSummaryCsv" -ForegroundColor Green

Write-Host ""
Write-Host "GETTING DETAILED HOP-BY-HOP RESULTS:" -ForegroundColor Yellow
Write-Host "Get-MessageTraceDetailV2 returns every transport event (deliver/expand/fail/transfer," -ForegroundColor Yellow
Write-Host "spam verdicts, applied rules, delays, etc.) for a specific message." -ForegroundColor Yellow
Write-Host ""
Write-Host "Examples:" -ForegroundColor Cyan
Write-Host "  # Single message (copy MessageTraceId + RecipientAddress from the summary CSV):" -ForegroundColor Gray
Write-Host "  Get-MessageTraceDetailV2 -MessageTraceId 'a1b2c3d4-...' -RecipientAddress 'user@contoso.com' | Format-List" -ForegroundColor White
Write-Host ""
Write-Host "  # First 10 messages from the summary:" -ForegroundColor Gray
Write-Host "  Import-Csv '$OutputSummaryCsv' | Select-Object -First 10 | ForEach-Object {" -ForegroundColor White
Write-Host "      Get-MessageTraceDetailV2 -MessageTraceId `$_.MessageTraceId -RecipientAddress `$_.RecipientAddress" -ForegroundColor White
Write-Host "  } | Export-Csv 'C:\Temp\Exchange\Detail_Sample.csv' -NoTypeInformation" -ForegroundColor White
Write-Host ""
Write-Host "Tips: Throttling = 100 detail requests per 5 minutes. Add Start-Sleep -Seconds 3 between batches." -ForegroundColor Yellow
