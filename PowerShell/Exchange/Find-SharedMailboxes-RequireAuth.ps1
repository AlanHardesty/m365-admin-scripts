# Find-SharedMailboxes-RequireAuth.ps1
# Read-only discovery script. Finds all shared mailboxes in a domain that have
# RequireSenderAuthenticationEnabled = True (blocks external/unauthenticated senders).
# Use Set-SharedMailboxes-RemoveAuthRequirement.ps1 to fix the identified mailboxes.
#
# Requires: ExchangeOnlineManagement

# ---- CONFIGURATION ----
$Domain    = "contoso.com"   # Domain to scan (without the @)
$OutputCsv = "C:\Temp\Exchange\SharedMailboxes_RequireAuth_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
# -----------------------

Connect-ExchangeOnline

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Shared Mailboxes — RequireSenderAuthentication Scan" -ForegroundColor Cyan
Write-Host "Domain: @$Domain" -ForegroundColor White
Write-Host "=======================================================" -ForegroundColor Cyan

$Results = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited |
    Where-Object {
        $_.RequireSenderAuthenticationEnabled -eq $true -and
        ($_.PrimarySmtpAddress -like "*@$Domain" -or $_.EmailAddresses -like "*@$Domain")
    } |
    Select-Object DisplayName, PrimarySmtpAddress, RequireSenderAuthenticationEnabled,
                  RecipientTypeDetails, WhenCreated, WhenChanged, Alias

if ($Results.Count -gt 0) {
    Write-Host "`nFound $($Results.Count) shared mailbox(es) blocking external senders:" -ForegroundColor Red
    $Results | Format-Table -AutoSize
    $Results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Report saved to: $OutputCsv" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Review the CSV. Copy the PrimarySmtpAddress values you want to fix." -ForegroundColor Yellow
    Write-Host "2. Run Set-SharedMailboxes-RemoveAuthRequirement.ps1 on the approved mailboxes." -ForegroundColor Yellow
}
else {
    Write-Host "`nNo shared mailboxes found with RequireSenderAuthenticationEnabled = True for @$Domain." -ForegroundColor Green
}

Disconnect-ExchangeOnline -Confirm:$false
