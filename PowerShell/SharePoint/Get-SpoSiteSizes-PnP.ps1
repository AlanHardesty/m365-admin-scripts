# Get-SpoSiteSizes-PnP.ps1
# Retrieves storage sizes for all SharePoint Online sites (including OneDrive)
# using PnP.PowerShell with an interactive browser login.
# Writes results to a JSON cache file for use by other scripts.
#
# NOTE: Run in a fresh terminal that has never loaded ExchangeOnlineManagement.
# PnP.PowerShell and ExchangeOnlineManagement conflict at the MSAL DLL level.
#
# Requires: PnP.PowerShell

param(
    [string]$SpoAdminUrl = "https://contoso-admin.sharepoint.com",
    [string]$ClientId    = "YOUR-PNP-CLIENT-ID",   # Entra app registration with SharePoint Admin consent
    [string]$CachePath   = "C:\Temp\spo-sites-cache.json"
)

if (Get-Module -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue) {
    Write-Host "ExchangeOnlineManagement is loaded — open a NEW terminal and re-run." -ForegroundColor Red
    exit 1
}

if (-not (Get-Module -ListAvailable -Name PnP.PowerShell -ErrorAction SilentlyContinue)) {
    Write-Host "Installing PnP.PowerShell..." -ForegroundColor Cyan
    Install-Module PnP.PowerShell -Scope CurrentUser -Force -ErrorAction Stop
}
Import-Module PnP.PowerShell -Force -ErrorAction Stop
Write-Host "PnP.PowerShell: $((Get-Module PnP.PowerShell).Version)" -ForegroundColor Cyan

if (-not (Test-Path (Split-Path $CachePath))) {
    New-Item -Path (Split-Path $CachePath) -ItemType Directory -Force | Out-Null
}

Write-Host "Connecting to SharePoint Online (browser will open)..." -ForegroundColor Yellow
try {
    $conn = Connect-PnPOnline -Url $SpoAdminUrl -Interactive -ClientId $ClientId -ReturnConnection -ErrorAction Stop
    Write-Host "Connected." -ForegroundColor Green
}
catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Fetching all site storage sizes (may take several minutes)..." -ForegroundColor Cyan
try {
    $sites = Get-PnPTenantSite -IncludeOneDriveSites -Connection $conn -ErrorAction Stop
    Write-Host "Retrieved $($sites.Count) site(s)" -ForegroundColor Green
}
catch {
    Write-Host "Site query failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$cache = $sites | ForEach-Object {
    [PSCustomObject]@{
        Url                 = $_.Url.TrimEnd('/')
        StorageUsageCurrent = $_.StorageUsageCurrent   # MB
    }
}

$cache | ConvertTo-Json -Depth 2 | Out-File -FilePath $CachePath -Encoding UTF8 -Force
Write-Host ""
Write-Host "Cache written: $CachePath ($($cache.Count) entries)" -ForegroundColor Green
