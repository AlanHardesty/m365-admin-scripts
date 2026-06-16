# New-SharedMailboxWithForwarding.ps1
# Creates shared mailboxes from a CSV and configures forwarding with copy retention.
# If the mailbox already exists, skips creation and goes straight to setting forwarding.
#
# Requires: ExchangeOnlineManagement
# CSV columns: "Routing Name", "email address", "Forwarding rule"

# ---- CONFIGURATION ----
$CsvPath = "C:\Temp\Exchange\mailboxes.csv"
# -----------------------

Connect-ExchangeOnline

$mailboxes = Import-Csv -Path $CsvPath -Delimiter ","

foreach ($entry in $mailboxes) {
    $routingName       = $entry.'Routing Name'.Trim()
    $emailAddress      = $entry.'email address'.Trim()
    $forwardingAddress = $entry.'Forwarding rule'.Trim()

    if ([string]::IsNullOrWhiteSpace($emailAddress)) {
        Write-Warning "Skipping row with missing email address"
        continue
    }

    Write-Host "Processing: $routingName ($emailAddress) -> $forwardingAddress" -ForegroundColor Cyan

    $existing = Get-Mailbox -Identity $emailAddress -ErrorAction SilentlyContinue

    if (-not $existing) {
        try {
            Write-Host "  Creating shared mailbox..." -ForegroundColor Yellow
            New-Mailbox -Shared -Name $routingName -PrimarySmtpAddress $emailAddress -ErrorAction Stop | Out-Null
            Start-Sleep -Seconds 20   # Allow provisioning to complete
            Write-Host "  Mailbox created." -ForegroundColor Green
        }
        catch {
            Write-Host "  ERROR creating mailbox: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }
    else {
        Write-Host "  Mailbox already exists." -ForegroundColor Green
    }

    try {
        Set-Mailbox -Identity $emailAddress `
                    -ForwardingSmtpAddress $forwardingAddress `
                    -DeliverToMailboxAndForward $true `
                    -ErrorAction Stop
        Write-Host "  Forwarding configured with retention enabled." -ForegroundColor Green
    }
    catch {
        Write-Host "  ERROR setting forwarding: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "----------------------------------------" -ForegroundColor DarkGray
}

Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Done." -ForegroundColor Green
