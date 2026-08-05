# Get-MailboxInventory.ps1
# Generates a comprehensive mailbox inventory report combining Exchange Online and
# Microsoft Graph data. Correctly identifies F3/F1-only users as effectively disabled
# for interactive login even when their AAD account is technically enabled.
#
# Report columns:
#   DisplayName, UPN, EmailAddress, MailboxType, AccountEnabled, EffectiveAccountEnabled,
#   EffectiveAccessReason, OnPremisesSyncEnabled, HiddenInGAL, MailboxAccessible,
#   ForwardsEnabled, ForwardedEmailAddress, AutoReplyEnabled, AutoReplyMessage,
#   LastSignInDate, Country, City, CompanyName, Department, LicensesAssigned,
#   OnPremisesDistinguishedName
#
# Output: Excel (requires ImportExcel module) or CSV fallback
#
# Requires: ExchangeOnlineManagement, Microsoft.Graph
# Optional: ImportExcel (for .xlsx output)

$exportPath = "C:\Temp\Exchange"

# License SKU classification
$F3OrRestrictedSkus = @("SPE_F3","DESKLESSPACK","M365_F1","SPE_F1")
$FullSignInSkus     = @("SPE_E5","SPE_E3","ENTERPRISEPREMIUM","ENTERPRISEPACK",
                        "OFFICESUBSCRIPTION","EXCHANGESTANDARD","EXCHANGEENTERPRISE")

try {
    Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All" -NoWelcome
    Write-Host "Connected to Microsoft Graph" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"; exit
}

try {
    Connect-ExchangeOnline -ShowBanner:$false
    Write-Host "Connected to Exchange Online" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Exchange Online: $_"; exit
}

Write-Host "Retrieving mailboxes..." -ForegroundColor Cyan
$mailboxes = Get-EXOMailbox -ResultSize Unlimited -Properties `
    ForwardingSmtpAddress, HiddenFromAddressListsEnabled,
    RecipientTypeDetails, OnPremisesSyncEnabled, OnPremisesDistinguishedName

Write-Host "Found $($mailboxes.Count) mailboxes. Processing..." -ForegroundColor Yellow

$report = @()

foreach ($mbx in $mailboxes) {
    $upn = $mbx.UserPrincipalName
    if (-not $upn) { continue }

    Write-Progress -Activity "Processing Mailboxes" -Status $upn -PercentComplete ($report.Count / $mailboxes.Count * 100)

    $user = $null
    try {
        $user = Get-MgUser -UserId $upn `
            -Property Id,DisplayName,UserPrincipalName,AccountEnabled,Country,City,CompanyName,Department `
            -ErrorAction Stop
    }
    catch { Write-Warning "Not found in Entra ID: $upn" }

    if (-not $user) {
        $report += [PSCustomObject]@{
            DisplayName = "NOT FOUND IN ENTRA ID"; UserPrincipalName = $upn
            EmailAddressPrimary = $mbx.PrimarySmtpAddress; MailboxType = $mbx.RecipientTypeDetails
            AccountEnabled = $false; EffectiveAccountEnabled = $false
            EffectiveAccessReason = "User missing in Entra ID"
            OnPremisesSyncEnabled = $mbx.OnPremisesSyncEnabled; HiddenInGAL = $mbx.HiddenFromAddressListsEnabled
            MailboxAccessible = $false; ForwardsEnabled = $false; ForwardedEmailAddress = $null
            AutoReplyEnabled = $false; AutoReplyMessage = $null; LastSignInDate = $null
            Country = $null; City = $null; CompanyName = $null; Department = $null; LicensesAssigned = $null
            OnPremisesDistinguishedName = $mbx.OnPremisesDistinguishedName
        }
        continue
    }

    $licenses = ""
    try { $licenses = (Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction Stop | Select-Object -ExpandProperty SkuPartNumber) -join "; " }
    catch { $licenses = "Error retrieving licenses" }

    $lastSignIn = $null
    try { $lastSignIn = (Get-MgUser -UserId $user.Id -Property SignInActivity -ErrorAction SilentlyContinue).SignInActivity.LastSignInDateTime }
    catch {}

    $autoReplyEnabled = $false; $autoReplyMessage = $null
    try {
        $auto = Get-MailboxAutoReplyConfiguration -Identity $mbx.Identity -ErrorAction Stop
        $autoReplyEnabled = ($auto.AutoReplyState -ne "Disabled")
        $autoReplyMessage = ($auto.ExternalMessage ?? $auto.InternalMessage)
        if ($autoReplyMessage) {
            $autoReplyMessage = $autoReplyMessage -replace "`r`n"," " -replace "\s+"," "
            if ($autoReplyMessage.Length -gt 500) { $autoReplyMessage = $autoReplyMessage.Substring(0,500) + "..." }
        }
    }
    catch {}

    $mailboxAccessible = $false
    try {
        $cas = Get-CASMailbox -Identity $mbx.Identity -ErrorAction Stop
        $mailboxAccessible = $cas.ActiveSyncEnabled -or $cas.OwaEnabled -or $cas.EwsEnabled -or $cas.MAPIEnabled
    }
    catch {}

    # Determine effective sign-in capability
    $aadEnabled      = $user.AccountEnabled
    $hasFullLicense  = ($licenses -split "; " | Where-Object { $_ -in $FullSignInSkus }).Count -gt 0
    $hasF3Only       = ($licenses -split "; " | Where-Object { $_ -in $F3OrRestrictedSkus }).Count -gt 0 -and -not $hasFullLicense

    if ($hasF3Only) {
        $effectiveEnabled = $false; $reason = "F3/F1 License Only (No interactive login)"
    }
    elseif (-not $aadEnabled) {
        $effectiveEnabled = $false; $reason = "Account Disabled in Entra ID"
    }
    else {
        $effectiveEnabled = $true; $reason = "Full License (E3/E5/O365)"
    }

    $report += [PSCustomObject]@{
        DisplayName                 = $user.DisplayName
        UserPrincipalName           = $user.UserPrincipalName
        EmailAddressPrimary         = $mbx.PrimarySmtpAddress
        MailboxType                 = $mbx.RecipientTypeDetails
        AccountEnabled              = $aadEnabled
        EffectiveAccountEnabled     = $effectiveEnabled
        EffectiveAccessReason       = $reason
        OnPremisesSyncEnabled       = $mbx.OnPremisesSyncEnabled
        HiddenInGAL                 = $mbx.HiddenFromAddressListsEnabled
        MailboxAccessible           = $mailboxAccessible
        ForwardsEnabled             = [bool]$mbx.ForwardingSmtpAddress
        ForwardedEmailAddress       = $mbx.ForwardingSmtpAddress
        AutoReplyEnabled            = $autoReplyEnabled
        AutoReplyMessage            = $autoReplyMessage
        LastSignInDate              = $lastSignIn
        Country                     = $user.Country
        City                        = $user.City
        CompanyName                 = $user.CompanyName
        Department                  = $user.Department
        LicensesAssigned            = $licenses
        OnPremisesDistinguishedName = $mbx.OnPremisesDistinguishedName
    }
}

if (-not (Test-Path $exportPath)) { New-Item -Path $exportPath -ItemType Directory -Force | Out-Null }

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$sorted    = $report | Sort-Object EffectiveAccountEnabled, DisplayName

if (Get-Module -ListAvailable -Name ImportExcel) {
    Import-Module ImportExcel -ErrorAction SilentlyContinue
    $xlsxPath = "$exportPath\MailboxInventory-$timestamp.xlsx"
    $sorted | Export-Excel -Path $xlsxPath -WorksheetName "Mailbox Inventory" `
        -AutoSize -TableName "MailboxReport" -Title "Mailbox Inventory" -TitleBold -FreezeTopRow
    Write-Host "Report exported to Excel: $xlsxPath" -ForegroundColor Green
}
else {
    $csvPath = "$exportPath\MailboxInventory-$timestamp.csv"
    $sorted | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "ImportExcel not available. Exported to CSV: $csvPath" -ForegroundColor Yellow
}

Write-Host "Complete. Total mailboxes: $($report.Count)" -ForegroundColor Green
