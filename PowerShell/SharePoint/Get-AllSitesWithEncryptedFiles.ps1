# Get-AllSitesWithEncryptedFiles.ps1
# Reports all SharePoint sites (active and archived) that contain files
# protected by sensitivity labels with encryption enabled.
# Uses compliance search per site to detect labeled content.
#
# Requires: Microsoft.Online.SharePoint.PowerShell, PnP.PowerShell,
#           Security & Compliance PowerShell (Connect-IPPSSession)

# ---- CONFIGURATION ----
$adminUrl  = "https://contoso-admin.sharepoint.com"
$outputCsv = "C:\Temp\AllSitesWithEncryptedFiles.csv"
# -----------------------

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -UseWindowsPowerShell
Import-Module PnP.PowerShell

Connect-SPOService -Url $adminUrl
Connect-IPPSSession

# Get all active and archived sites
$activeSites   = Get-SPOSite -Limit All | Select-Object Url, Title, ArchiveStatus, LastContentModifiedDate
$archivedSites = Get-SPOSite -ArchiveStatus Archived -Limit All | Select-Object Url, Title, ArchiveStatus, LastContentModifiedDate
$allSites      = $activeSites + $archivedSites

if ($allSites.Count -eq 0) {
    Write-Host "No sites found." -ForegroundColor Yellow
    return
}

# Find all sensitivity labels that have encryption enabled
$labels             = Get-Label
$encryptingLabelGuids = @()

foreach ($label in $labels) {
    if ($label.LabelActions) {
        $actions       = $label.LabelActions | ConvertFrom-Json
        $encryptAction = $actions | Where-Object { $_.Type -eq "encrypt" }

        if ($encryptAction) {
            $settings = $encryptAction.Settings | ConvertFrom-Json
            $disabled = $settings | Where-Object { $_.Key -eq "disabled" } | Select-Object -ExpandProperty Value
            if ($disabled -eq "false") {
                $encryptingLabelGuids += $label.Guid
            }
        }
    }
}

if ($encryptingLabelGuids.Count -eq 0) {
    Write-Host "No sensitivity labels with encryption found in the tenant." -ForegroundColor Yellow
    return
}

$query  = "sensitivitylabel:($($encryptingLabelGuids -join ' OR '))"
$report = @()

foreach ($site in $allSites) {
    $searchName = "Temp_EncCheck_$($site.Url -replace '[:/]','_')"

    New-ComplianceSearch -Name $searchName `
        -SharePointLocation $site.Url `
        -ContentMatchQuery $query `
        -AllowNotFoundSearchLocations $true `
        -Description "Temp search for encrypted files" | Out-Null

    Start-ComplianceSearch -Identity $searchName

    $timeout   = (Get-Date).AddMinutes(10)
    $completed = $false

    while ((Get-Date) -lt $timeout) {
        $search = Get-ComplianceSearch -Identity $searchName
        if ($search.Status -eq "Completed") { $completed = $true; break }
        Start-Sleep -Seconds 30
    }

    $hasEncrypted = if ($completed -and $search.Items -gt 0) {
        "Yes ($($search.Items) files matched)"
    }
    elseif (-not $completed) {
        "Timeout - Check manually"
    }
    else { "No" }

    $report += [PSCustomObject]@{
        SiteUrl                 = $site.Url
        Title                   = $site.Title
        ArchiveStatus           = $site.ArchiveStatus
        IsArchived              = if ($site.ArchiveStatus -eq "Archived") { "Yes" } else { "No" }
        LastContentModifiedDate = $site.LastContentModifiedDate
        HasEncryptedFiles       = $hasEncrypted
    }

    Remove-ComplianceSearch -Identity $searchName -Confirm:$false
    Write-Host "$($site.Title): $hasEncrypted"
}

$report | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Done. Report for $($allSites.Count) sites exported to: $outputCsv" -ForegroundColor Green

Disconnect-SPOService
