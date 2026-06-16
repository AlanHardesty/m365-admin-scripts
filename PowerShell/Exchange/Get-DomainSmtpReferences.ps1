# Get-DomainSmtpReferences.ps1
# Scans Exchange Online recipients for all email addresses matching a list of domains.
# Useful for auditing which recipients reference a domain before decommissioning it.
#
# Requires: ExchangeOnlineManagement
# Input CSV column: Domain (one domain per row, no @ prefix)

# ---- CONFIGURATION ----
$domainsCsvPath = "C:\Temp\Domain-SMTPcheck\Domains.csv"
$reportPath     = "C:\Temp\Domain-SMTPcheck\ExchangeRecipientReferences.csv"
# -----------------------

Connect-ExchangeOnline

$domains = Import-Csv -Path $domainsCsvPath | Select-Object -ExpandProperty Domain

if ($domains.Count -eq 0) {
    Write-Host "No domains found in $domainsCsvPath." -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false
    exit
}

$report = @()

foreach ($domain in $domains) {
    Write-Host "Scanning for domain: $domain..." -ForegroundColor Green

    $recipients = Get-Recipient -Filter "EmailAddresses -like '*@$domain*'" -ResultSize Unlimited |
        Select-Object Identity, DisplayName, PrimarySmtpAddress, RecipientType, EmailAddresses

    foreach ($recipient in $recipients) {
        $matchingEmails = ($recipient.EmailAddresses | Where-Object { $_ -like "*@$domain*" }) -join "; "

        $report += [PSCustomObject]@{
            Domain                 = $domain
            Identity               = $recipient.Identity
            DisplayName            = $recipient.DisplayName
            PrimarySmtpAddress     = $recipient.PrimarySmtpAddress
            RecipientType          = $recipient.RecipientType
            MatchingEmailAddresses = $matchingEmails
        }
    }
}

if ($report.Count -gt 0) {
    $report | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report exported to $reportPath ($($report.Count) recipients across $($domains.Count) domain(s))" -ForegroundColor Green

    $report | Group-Object Domain, RecipientType |
        Select-Object @{Name="Domain";       Expression={$_.Name.Split(',')[0]}},
                      @{Name="RecipientType"; Expression={$_.Name.Split(',')[1].Trim()}},
                      Count |
        Sort-Object Domain, RecipientType |
        Format-Table -AutoSize
}
else {
    Write-Host "No recipients found for any of the specified domains." -ForegroundColor Yellow
}

Disconnect-ExchangeOnline -Confirm:$false
