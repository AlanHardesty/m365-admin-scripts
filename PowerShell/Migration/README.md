# M365 Tenant-to-Tenant User Migration Scripts

A numbered sequence of PowerShell scripts for migrating users from one Microsoft 365 tenant to another. Each script handles a specific phase of the migration workflow and is designed to be run against a batch CSV file.

## Prerequisites

| Module | Install Command |
|--------|----------------|
| Microsoft.Graph | `Install-Module Microsoft.Graph` |
| PnP.PowerShell | `Install-Module PnP.PowerShell` |
| MicrosoftTeams | `Install-Module MicrosoftTeams` |
| Microsoft.Online.SharePoint.PowerShell | `Install-Module Microsoft.Online.SharePoint.PowerShell` |
| ActiveDirectory | Available via RSAT |

## Configuration

Before running any script, update the following values:

```powershell
$tenantName    = "contoso.onmicrosoft.com"       # Your source tenant
$adminUrl      = "https://contoso-admin.sharepoint.com"
$pnpClientId   = "YOUR-PNP-CLIENT-ID"            # Entra app registration client ID
$myAdminName   = "admin@contoso.onmicrosoft.com" # Your admin UPN (used in scripts 42, 44)
```

## CSV Format

All scripts expect a CSV file with the following columns:

| Column | Description |
|--------|-------------|
| `SourceUpn` | UPN of the user in the source tenant |
| `TargetUpn` | UPN of the user's guest/target account in the source tenant |
| `TargetEmail` | New email address in the target tenant (used in autoreply scripts) |

## Script Sequence

| Script | Phase | Description |
|--------|-------|-------------|
| 10 | Pre-migration | Inventory legacy SharePoint site permissions |
| 11 | Pre-migration | Verify source and target accounts exist |
| 12 | Migration | Add legacy SPO permissions to target user |
| 13 | Migration | Add target user to Office 365 groups |
| 14 | Migration | Enable email forwarding and add to forwarding group |
| 15 | Migration | Add target user to Teams private channels |
| 20 | Migration | Update mail contact external email address |
| 21 | Migration | Set up auto-reply on source mailbox |
| 30 | Migration | Update Active Directory group membership |
| 31 | Post-migration | Restrict source mailbox client access |
| 32 | Post-migration | Set source OneDrive to NoAccess |
| 33 | Post-migration | Remove source user from Office 365 groups |
| 34 | Post-migration | Remove legacy SPO permissions from source user |
| 35 | Post-migration | Re-enable OneDrive access (if needed) |
| 41 | Teams | Disable private channel creation on Teams |
| 42 | Teams | Demote team owners and set SharePoint sites to ReadOnly |
| 44 | Post-migration | Disable shared mailbox client access and remove permissions |

## Notes

- Scripts 10 and 34 work together — run 10 first to generate the permissions report, then use that report as input to 34.
- Scripts that modify data include a test-run comment — comment out the action line to do a dry run first.
- Scripts 32 and 35 are inverse operations (lock/unlock OneDrive).
- Script 42 requires the admin account to be added temporarily as a site collection admin for public archived Teams sites.
