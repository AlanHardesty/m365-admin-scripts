# Set-BulkEmailForwarding.ps1
# Sets SMTP forwarding on source mailboxes to target addresses from a CSV.
# Does NOT keep a copy in the source mailbox (DeliverToMailboxAndForward = $false).
# Use Set-EmailForwarding-WithRetention.ps1 if you want to keep a copy.
#
# Requires: ExchangeOnlineManagement
# CSV columns: SourceEmail, TargetEmail

# ---- CONFIGURATION ----
$csvPath = "C:\Temp\users.csv"
# -----------------------

Connect-ExchangeOnline

$emailMappings = Import-Csv -Path $csvPath -Delimiter ","

foreach ($mapping in $emailMappings) {
    $sourceEmail = $mapping.SourceEmail
    $targetEmail = $mapping.TargetEmail

    if (-not [string]::IsNullOrWhiteSpace($sourceEmail) -and -not [string]::IsNullOrWhiteSpace($targetEmail)) {
        try {
            Set-Mailbox -Identity $sourceEmail `
                        -ForwardingSmtpAddress $targetEmail `
                        -DeliverToMailboxAndForward $false `
                        -ErrorAction Stop
            Write-Host "Forwarding set: $sourceEmail -> $targetEmail" -ForegroundColor Green
        }
        catch {
            Write-Host "Error setting forwarding for $sourceEmail -> $targetEmail : $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Skipping row — missing SourceEmail or TargetEmail" -ForegroundColor Yellow
    }
}

Disconnect-ExchangeOnline -Confirm:$false
