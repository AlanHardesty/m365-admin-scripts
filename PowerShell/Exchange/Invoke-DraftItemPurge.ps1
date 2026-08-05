# Invoke-DraftItemPurge.ps1
# Purges all items from the Drafts folder of a mailbox using a compliance search.
# Temporarily disables Single Item Recovery if needed to allow permanent deletion,
# then re-enables it afterward.
#
# Requires: ExchangeOnlineManagement, Security & Compliance PowerShell (Connect-IPPSSession)

# ---- CONFIGURATION ----
$mailbox    = "user@contoso.com"   # Mailbox to purge Drafts from
$searchName = "PurgeDrafts"
# -----------------------

Connect-ExchangeOnline
Connect-IPPSSession

Write-Host "Checking retention settings for $mailbox..." -ForegroundColor Green
$mailboxConfig = Get-Mailbox -Identity $mailbox
Write-Host "LitigationHoldEnabled     : $($mailboxConfig.LitigationHoldEnabled)" -ForegroundColor Yellow
Write-Host "SingleItemRecoveryEnabled : $($mailboxConfig.SingleItemRecoveryEnabled)" -ForegroundColor Yellow

if ($mailboxConfig.SingleItemRecoveryEnabled) {
    Write-Host "Temporarily disabling Single Item Recovery to allow permanent deletion..." -ForegroundColor Yellow
    Set-Mailbox -Identity $mailbox -SingleItemRecoveryEnabled $false
}

# Get Drafts folder name (localized environments may differ)
$draftsFolder = Get-MailboxFolderStatistics -Identity $mailbox -FolderScope Drafts | Select-Object -First 1
if (-not $draftsFolder) {
    Write-Host "Could not retrieve Drafts folder. Exiting." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

Write-Host "Drafts folder: $($draftsFolder.Name) — $($draftsFolder.ItemsInFolder) items" -ForegroundColor Green

# Remove existing search if it exists
if (Get-ComplianceSearch -Identity $searchName -ErrorAction SilentlyContinue) {
    Remove-ComplianceSearch -Identity $searchName -Confirm:$false
}

$searchQuery = "IsDraft:true folder:$($draftsFolder.Name)"
New-ComplianceSearch -Name $searchName -ExchangeLocation $mailbox -ContentMatchQuery $searchQuery
Start-ComplianceSearch -Identity $searchName

do {
    Start-Sleep -Seconds 30
    $searchStatus = Get-ComplianceSearch -Identity $searchName
    Write-Host "Search status: $($searchStatus.Status) — Items: $($searchStatus.Items)" -ForegroundColor Cyan
} while ($searchStatus.Status -ne "Completed")

$itemsFound = $searchStatus.Items

if ($itemsFound -gt 0) {
    do {
        Write-Host "Purging $itemsFound items..." -ForegroundColor Green
        New-ComplianceSearchAction -SearchName $searchName -Purge -PurgeType HardDelete -Confirm:$false
        $purgeActionName = "${searchName}_Purge"

        do {
            Start-Sleep -Seconds 60
            $purgeStatus = Get-ComplianceSearchAction -Identity $purgeActionName
            Write-Host "Purge status: $($purgeStatus.Status)" -ForegroundColor Green
        } while ($purgeStatus.Status -ne "Completed")

        $purgeItemCount = if ($purgeStatus.Results -match "Item count: (\d+)") { $Matches[1] } else { 0 }
        Write-Host "Items reported purged: $purgeItemCount" -ForegroundColor Cyan

        # Re-search to confirm
        Remove-ComplianceSearch -Identity $searchName -Confirm:$false
        New-ComplianceSearch -Name $searchName -ExchangeLocation $mailbox -ContentMatchQuery $searchQuery
        Start-ComplianceSearch -Identity $searchName

        do {
            Start-Sleep -Seconds 30
            $searchStatus = Get-ComplianceSearch -Identity $searchName
        } while ($searchStatus.Status -ne "Completed")

        $itemsFound = $searchStatus.Items
        Write-Host "Remaining items: $itemsFound" -ForegroundColor Cyan

    } while ($itemsFound -gt 0 -and $purgeItemCount -gt 0)

    $postFolder = Get-MailboxFolderStatistics -Identity $mailbox -FolderScope Drafts | Select-Object -First 1
    Write-Host "Drafts items after purge: $($postFolder.ItemsInFolder)" -ForegroundColor Green
}
else {
    Write-Host "No draft items found." -ForegroundColor Cyan
}

# Restore Single Item Recovery
if ($mailboxConfig.SingleItemRecoveryEnabled) {
    Set-Mailbox -Identity $mailbox -SingleItemRecoveryEnabled $true
    Write-Host "Single Item Recovery re-enabled." -ForegroundColor Green
}
