# Invoke-ComplianceSearchPurge.ps1
# Loops a compliance search purge action until no items remain.
# Each purge pass hard-deletes up to 10 items per mailbox (Microsoft's per-action limit).
# The loop re-runs the search and creates a new purge action until count reaches 0.
#
# Requires: Security & Compliance PowerShell (Connect-IPPSSession)
# Prerequisites: A compliance search must already exist and be in a Completed state.

# ---- CONFIGURATION ----
$searchName = "YourComplianceSearchName"   # Name of the existing compliance search
# -----------------------

Connect-IPPSSession

function Get-SearchItemCount {
    param ([string]$Name)
    Start-ComplianceSearch -Identity $Name
    do {
        Start-Sleep -Seconds 10
        $s = Get-ComplianceSearch -Identity $Name
        Write-Host "  Search status: $($s.Status)" -ForegroundColor Cyan
    } while ($s.Status -ne "Completed")

    if ($s.SearchStatistics) {
        try {
            $stats = $s.SearchStatistics | ConvertFrom-Json
            if ($stats.ExchangeBinding.Search.ContentItems) {
                return [int]$stats.ExchangeBinding.Search.ContentItems
            }
        }
        catch { Write-Host "  Could not parse SearchStatistics" -ForegroundColor Yellow }
    }
    return 0
}

Write-Host "Starting purge loop for search: $searchName" -ForegroundColor Green

$initialCount = Get-SearchItemCount -Name $searchName
Write-Host "Initial item count: $initialCount" -ForegroundColor Cyan

if ($initialCount -eq 0) {
    Write-Host "No items found. Verify the search configuration." -ForegroundColor Yellow
    exit
}

$currentCount = $initialCount
$totalPurged  = 0
$pass         = 1

while ($currentCount -gt 0) {
    Write-Host "Pass $pass — purging..." -ForegroundColor Green

    $action     = New-ComplianceSearchAction -SearchName $searchName -Purge -PurgeType HardDelete -Confirm:$false
    $actionName = $action.Name

    do {
        Start-Sleep -Seconds 10
        $action = Get-ComplianceSearchAction -Identity $actionName
    } while ($action.Status -ne "Completed")

    Write-Host "  Results: $($action.Results)" -ForegroundColor Cyan

    $match          = [regex]::Match($action.Results, "Item count:\s*(\d+)")
    $reportedPurged = if ($match.Success) { [int]$match.Groups[1].Value } else { 0 }
    Write-Host "  Reported purged: $reportedPurged" -ForegroundColor Cyan

    Remove-ComplianceSearchAction -Identity $actionName -Confirm:$false

    Write-Host "  Waiting 120 seconds for deletions to process..." -ForegroundColor Cyan
    Start-Sleep -Seconds 120

    $newCount      = Get-SearchItemCount -Name $searchName
    $actualPurged  = $currentCount - $newCount
    $totalPurged  += $actualPurged
    $currentCount  = $newCount

    Write-Host "  Actually purged: $actualPurged | Total purged: $totalPurged | Remaining: $currentCount" -ForegroundColor Magenta

    if ($actualPurged -eq 0) {
        Write-Host "No items purged in this pass. Exiting loop." -ForegroundColor Yellow
        break
    }

    $pass++
}

Write-Host ""
Write-Host "Final item count : $currentCount" -ForegroundColor Green
Write-Host "Total purged     : $totalPurged"  -ForegroundColor Green

if ($currentCount -eq 0) {
    Write-Host "All items purged successfully." -ForegroundColor Green
}
else {
    Write-Host "Warning: $currentCount items remain. Investigate manually." -ForegroundColor Red
}
