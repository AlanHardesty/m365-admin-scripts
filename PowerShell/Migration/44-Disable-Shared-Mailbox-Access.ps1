# 44 - Disable Shared Mailbox Access
# For each mailbox in the CSV:
#   1. Disables all client access protocols
#   2. Removes all Full Access permissions
#   3. Removes all Send As permissions
#   4. Clears Send on Behalf permissions
#
# Requires: ExchangeOnlineManagement
# CSV columns: SourceUpn

# ---- CONFIGURATION ----
$csvPath = "C:\Temp\SharedMailboxes\users.csv"
# -----------------------

Connect-ExchangeOnline

$mailboxes = Import-Csv -Path $csvPath

foreach ($mailbox in $mailboxes) {
    $upn = $mailbox.SourceUpn.Trim()
    Write-Host "Processing: $upn" -ForegroundColor Cyan

    try {
        $mailboxObject = Get-Mailbox -Identity $upn -ErrorAction Stop

        # Disable all client access protocols
        Set-CASMailbox -Identity $upn `
            -OWAEnabled $false -OWAforDevicesEnabled $false `
            -PopEnabled $false -ActiveSyncEnabled $false `
            -EwsAllowEntourage $false -EwsAllowOutlook $false -EwsAllowMacOutlook $false `
            -EwsEnabled $false -ImapEnabled $false `
            -MacOutlookEnabled $false -UniversalOutlookEnabled $false `
            -MAPIEnabled $false -OutlookMobileEnabled $false `
            -ErrorAction Stop
        Write-Host " Client access disabled" -ForegroundColor Green

        # Remove Full Access permissions
        $fullAccessUsers = Get-MailboxPermission -Identity $upn |
            Where-Object { $_.AccessRights -eq "FullAccess" -and $_.User -notlike "NT AUTHORITY\*" }
        foreach ($u in $fullAccessUsers) {
            Remove-MailboxPermission -Identity $upn -User $u.User -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop
            Write-Host " Removed FullAccess for $($u.User)" -ForegroundColor Green
        }

        # Remove Send As permissions
        $mailboxDN = $mailboxObject.DistinguishedName
        $sendAsUsers = Get-RecipientPermission -Identity $mailboxDN |
            Where-Object { $_.AccessRights -eq "SendAs" -and $_.Trustee -notlike "NT AUTHORITY\*" }
        foreach ($u in $sendAsUsers) {
            Remove-RecipientPermission -Identity $mailboxDN -Trustee $u.Trustee -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            Write-Host " Removed SendAs for $($u.Trustee)" -ForegroundColor Green
        }

        # Clear Send on Behalf
        Set-Mailbox -Identity $upn -GrantSendOnBehalfTo $null -ErrorAction Stop
        Write-Host " Cleared Send on Behalf permissions" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to process $upn : $_"
    }
}
