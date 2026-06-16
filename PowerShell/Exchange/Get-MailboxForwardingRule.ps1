# Get-MailboxForwardingRule.ps1
# Checks all forwarding configurations on a mailbox:
#   1. Mailbox-level forwarding (ForwardingSmtpAddress / ForwardingAddress)
#   2. Inbox rules that forward or redirect messages
#
# Requires: ExchangeOnlineManagement

# ---- CONFIGURATION ----
$mailboxIdentity = "user@contoso.com"   # UPN or primary SMTP address to check
# -----------------------

Connect-ExchangeOnline

Write-Host "`n==============================================================" -ForegroundColor Green
Write-Host "   FORWARDING CHECK FOR: $mailboxIdentity" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green

# === 1. Mailbox-level forwarding ===
Write-Host "`n--- 1. MAILBOX-LEVEL FORWARDING ---" -ForegroundColor Yellow

$mbx = Get-EXOMailbox -Identity $mailboxIdentity `
    -Properties ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward, PrimarySmtpAddress

$resolvedForwardingTarget = $null
if ($mbx.ForwardingAddress) {
    try {
        $resolvedForwardingTarget = (Get-EXORecipient -Identity $mbx.ForwardingAddress -ErrorAction Stop).PrimarySmtpAddress
    }
    catch {
        $resolvedForwardingTarget = "Could not resolve (raw value: $($mbx.ForwardingAddress))"
    }
}

$mbx | Select-Object PrimarySmtpAddress,
    @{Name="ForwardingSmtpAddress (External)";       Expression={$_.ForwardingSmtpAddress}},
    @{Name="ForwardingAddress (Raw)";                Expression={$_.ForwardingAddress}},
    @{Name="Resolved Forwarding Target (Full SMTP)"; Expression={$resolvedForwardingTarget}},
    DeliverToMailboxAndForward |
    Format-List

if ($resolvedForwardingTarget -and $resolvedForwardingTarget -notlike "*Could not resolve*") {
    Write-Host ">>> MAIL IS BEING FORWARDED TO: $resolvedForwardingTarget" -ForegroundColor Red
}

# === 2. Inbox rules with forwarding actions ===
Write-Host "`n--- 2. INBOX RULES THAT FORWARD / REDIRECT ---" -ForegroundColor Yellow

$rules = Get-InboxRule -Mailbox $mailboxIdentity -IncludeHidden |
    Where-Object { $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo }

if ($rules) {
    foreach ($rule in $rules) {
        Write-Host "`nRule: $($rule.Name)" -ForegroundColor Cyan
        $rule | Select-Object Enabled, Priority,
            @{Name="ForwardTo";              Expression={$_.ForwardTo -join "; "}},
            @{Name="ForwardAsAttachmentTo";  Expression={$_.ForwardAsAttachmentTo -join "; "}},
            @{Name="RedirectTo";             Expression={$_.RedirectTo -join "; "}},
            Description |
            Format-List
    }
}
else {
    Write-Host "No inbox rules with forwarding actions found." -ForegroundColor Yellow
}

Write-Host "`n==============================================================" -ForegroundColor Green
Disconnect-ExchangeOnline -Confirm:$false
