# Get-SpoSiteSizes-DeviceCode.ps1
# Retrieves SharePoint Online site storage sizes using the Microsoft identity platform
# v2.0 device code flow — no app registration required.
# Uses the well-known SharePoint Online Management Shell public client ID
# (pre-consented in all M365 tenants).
#
# Resolves AADSTS900561 errors seen with the deprecated v1 /oauth2/devicecode endpoint
# by targeting the v2.0 /oauth2/v2.0/devicecode endpoint, which returns
# verification_uri = https://microsoft.com/devicelogin (accepts standard browser GET).
#
# Writes results to a JSON cache file for use by other scripts.
#
# Requires: No external modules — uses Invoke-RestMethod only

param(
    [string]$TenantDomain = "contoso.onmicrosoft.com",
    [string]$SpoAdminUrl  = "https://contoso-admin.sharepoint.com",
    [string]$CachePath    = "C:\Temp\spo-sites-cache.json"
)

# SharePoint Online Management Shell — well-known Microsoft public client,
# pre-consented in all M365 tenants, supports device code flow for SPO Admin APIs.
$ClientId = "9bc3ab49-b65d-410a-85ad-de819febfddc"
$Scope    = "$SpoAdminUrl/.default"

if (-not (Test-Path (Split-Path $CachePath))) {
    New-Item -Path (Split-Path $CachePath) -ItemType Directory -Force | Out-Null
}

# ── 1. Request device code ───────────────────────────────────────────────────
Write-Host "Requesting device code (Microsoft identity platform v2.0)..." -ForegroundColor Cyan
try {
    $dcResp = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantDomain/oauth2/v2.0/devicecode" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "client_id=$ClientId&scope=$([Uri]::EscapeDataString($Scope))" `
        -ErrorAction Stop
}
catch {
    Write-Host "Device code request failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host $dcResp.message -ForegroundColor Yellow

# ── 2. Poll for token ────────────────────────────────────────────────────────
$token    = $null
$expiry   = (Get-Date).AddSeconds([int]$dcResp.expires_in)
$interval = [Math]::Max([int]$dcResp.interval, 5) + 1

Write-Host ""
Write-Host "Polling for authentication..." -ForegroundColor Cyan

while ((Get-Date) -lt $expiry -and -not $token) {
    Start-Sleep -Seconds $interval
    try {
        $tokenResp = Invoke-RestMethod -Method Post `
            -Uri "https://login.microsoftonline.com/$TenantDomain/oauth2/v2.0/token" `
            -ContentType "application/x-www-form-urlencoded" `
            -Body "client_id=$ClientId&grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=$($dcResp.device_code)" `
            -ErrorAction Stop
        $token = $tokenResp.access_token
        Write-Host "`nAuthenticated." -ForegroundColor Green
    }
    catch {
        $errBody = $null
        try { $errBody = $_.ErrorDetails.Message | ConvertFrom-Json } catch {}
        $errCode = if ($errBody) { $errBody.error } else { "" }
        switch ($errCode) {
            "authorization_pending" { Write-Host "." -NoNewline }
            "authorization_declined" { Write-Host "`nAuthentication declined." -ForegroundColor Red; exit 1 }
            "expired_token"          { Write-Host "`nDevice code expired — re-run the script." -ForegroundColor Red; exit 1 }
            "bad_verification_code"  { Write-Host "`nInvalid device code — re-run the script." -ForegroundColor Red; exit 1 }
            default { Write-Host "`nToken error ($errCode): $($_.ErrorDetails.Message)" -ForegroundColor Red; exit 1 }
        }
    }
}
if (-not $token) { Write-Host "`nAuthentication timed out — re-run the script." -ForegroundColor Red; exit 1 }

# ── 3. Collect site storage sizes via SPO Admin REST API ────────────────────
$headers    = @{ Authorization = "Bearer $token"; Accept = "application/json;odata=verbose" }
$allSites   = [System.Collections.Generic.List[object]]::new()
$startIndex = 0

Write-Host ""
Write-Host "Fetching SharePoint site storage data..." -ForegroundColor Cyan

do {
    $uri = "$SpoAdminUrl/_api/SPO.Tenant/GetAllSiteProperties2(startIndex=$startIndex,includeDetail=true)"
    try {
        $page    = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        $results = @($page.d.results)
    }
    catch {
        Write-Host "Site query failed at startIndex=$startIndex : $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    foreach ($s in $results) {
        $allSites.Add([PSCustomObject]@{
            Url                 = $s.Url
            StorageUsageCurrent = $s.StorageUsageCurrent
        })
    }

    $startIndex = $allSites.Count
    if ($results.Count -gt 0) { Write-Host "  $($allSites.Count) site(s) retrieved..." -ForegroundColor Cyan }

} while ($results.Count -gt 0)

Write-Host "Total sites: $($allSites.Count)" -ForegroundColor Green

# ── 4. Write cache ───────────────────────────────────────────────────────────
$allSites | ConvertTo-Json -Depth 2 | Out-File -FilePath $CachePath -Encoding UTF8 -Force
Write-Host "Cache written: $CachePath" -ForegroundColor Green
