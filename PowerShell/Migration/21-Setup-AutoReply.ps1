# 21 - Set Up Auto-Reply on Source Mailbox
# Enables an Out of Office auto-reply on the source mailbox directing senders to the
# user's new email address. Validates that the target email matches a proxy address
# on the target account before applying.
#
# Requires: Microsoft.Graph, ExchangeOnlineManagement
# CSV columns: SourceUpn, TargetUpn, TargetEmail

# ---- CONFIGURATION ----
$tenantName = "contoso.onmicrosoft.com"
$csvPath    = "C:\Temp\users.csv"
# -----------------------

$csv = Import-Csv $csvPath
Write-Host "CSV contains $($csv.Count) users"

Connect-MgGraph -TenantId $tenantName
Connect-ExchangeOnline

foreach ($user in $csv) {
    $sourceUpn  = $user.SourceUpn
    $targetUpn  = $user.TargetUpn
    $targetEmail = $user.TargetEmail

    Write-Host "$sourceUpn"

    $sourceUser = Get-MgUser -UserId $sourceUpn -ErrorAction SilentlyContinue
    $targetUser = Get-MgUser -UserId $targetUpn -Property Mail,ProxyAddresses -ErrorAction SilentlyContinue
    $mailbox    = Get-Mailbox -Identity $sourceUpn -ErrorAction SilentlyContinue

    if ($mailbox) {
        if ($targetUser) {
            if (-not ($targetUser.ProxyAddresses | Where-Object { $_ -match $targetEmail })) {
                Write-Host " -> Warning: TargetEmail in CSV does not match proxy addresses on $targetUpn" -ForegroundColor Cyan
                Write-Host "    Proxy addresses: $($targetUser.ProxyAddresses)" -ForegroundColor Gray
                Write-Host "    TargetEmail in CSV: $targetEmail" -ForegroundColor Gray
            }
        }
        else {
            Write-Host " -> Note: $targetUpn not found in Entra ID — could not verify TargetEmail" -ForegroundColor Cyan
        }

        if ($targetEmail) {
            $message = "Hi, your email has been forwarded to my new address: $targetEmail. Please use this address for all future correspondence. Thank you!"

            try {
                Write-Host " -> Setting auto-reply" -ForegroundColor Green
                Set-Mailbox -Identity $sourceUpn -DeliverToMailboxAndForward $true
                Set-MailboxAutoReplyConfiguration -Identity $sourceUpn `
                    -AutoReplyState Enabled `
                    -InternalMessage $message `
                    -ExternalMessage $message `
                    -ExternalAudience All
            }
            catch {
                Write-Host " -> Failed to set auto-reply for $sourceUpn" -ForegroundColor Red
            }
        }
        else {
            Write-Host " -> No TargetEmail specified for $sourceUpn — skipping auto-reply" -ForegroundColor Red
        }
    }
    else {
        Write-Host " -> Mailbox not found for $sourceUpn" -BackgroundColor Red
    }
}
