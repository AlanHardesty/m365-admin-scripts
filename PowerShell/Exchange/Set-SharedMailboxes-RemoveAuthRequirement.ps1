# Set-SharedMailboxes-RemoveAuthRequirement.ps1
# Finds all shared mailboxes in a domain with RequireSenderAuthenticationEnabled = True,
# shows them, exports a CSV, then asks for explicit confirmation before making any changes.
#
# Safe — will never modify anything without explicit YES confirmation.
# Companion to Find-SharedMailboxes-RequireAuth.ps1 (discovery-only version).
#
# Requires: ExchangeOnlineManagement

# ---- CONFIGURATION ----
$Domain    = "contoso.com"
$OutputCsv = "C:\Temp\Exchange\SharedMailboxes_RequireAuth_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
# -----------------------

Connect-ExchangeOnline

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Shared Mailbox Authentication Requirement — Audit & Fix" -ForegroundColor Cyan
Write-Host "Domain: @$Domain" -ForegroundColor White
Write-Host "=======================================================" -ForegroundColor Cyan

Write-Host "`nStep 1: Discovering affected mailboxes..." -ForegroundColor Yellow

$Results = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited |
    Where-Object {
        $_.RequireSenderAuthenticationEnabled -eq $true -and
        ($_.PrimarySmtpAddress -like "*@$Domain" -or $_.EmailAddresses -like "*@$Domain")
    } |
    Select-Object DisplayName, PrimarySmtpAddress, RequireSenderAuthenticationEnabled,
                  RecipientTypeDetails, WhenCreated, WhenChanged

if ($Results.Count -eq 0) {
    Write-Host "`nNo affected shared mailboxes found for @$Domain." -ForegroundColor Green
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

Write-Host "`nFound $($Results.Count) mailbox(es) currently blocking external senders:" -ForegroundColor Red
$Results | Format-Table -AutoSize
$Results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Report saved to: $OutputCsv" -ForegroundColor Gray

Write-Host "`n=======================================================" -ForegroundColor Yellow
Write-Host "WARNING: This will ALLOW external senders to reach the mailboxes above." -ForegroundColor Red
Write-Host "=======================================================" -ForegroundColor Yellow

$Confirmation = Read-Host "`nType YES to disable RequireSenderAuthenticationEnabled on all $($Results.Count) mailboxes (anything else cancels)"

if ($Confirmation -ne "YES") {
    Write-Host "`nCancelled. No changes were made." -ForegroundColor Green
    exit
}

Write-Host "`nStep 2: Applying changes..." -ForegroundColor Cyan

$SuccessCount = 0
$FailCount    = 0

foreach ($Mailbox in $Results) {
    try {
        Write-Host "  Updating: $($Mailbox.PrimarySmtpAddress) ..." -ForegroundColor White
        Set-Mailbox $Mailbox.PrimarySmtpAddress -RequireSenderAuthenticationEnabled $false -ErrorAction Stop
        $SuccessCount++
    }
    catch {
        Write-Warning "  Failed: $($Mailbox.PrimarySmtpAddress) — $_"
        $FailCount++
    }
}

Write-Host "`n=======================================================" -ForegroundColor Green
Write-Host "Successfully updated : $SuccessCount" -ForegroundColor Green
Write-Host "Failed               : $FailCount" -ForegroundColor $(if ($FailCount -gt 0) {"Red"} else {"Green"})
Write-Host "=======================================================" -ForegroundColor Green

Write-Host "`nStep 3: Verification (should now show False)..." -ForegroundColor Cyan
$Results | ForEach-Object {
    Get-Mailbox $_.PrimarySmtpAddress |
        Select-Object DisplayName, PrimarySmtpAddress, RequireSenderAuthenticationEnabled
} | Format-Table -AutoSize

Write-Host "`nDone. Allow 5-15 minutes for changes to propagate before testing." -ForegroundColor Green
Write-Host "Report saved to: $OutputCsv" -ForegroundColor Gray

Disconnect-ExchangeOnline -Confirm:$false
