# M365 Admin Scripts

PowerShell tooling and operational documentation for Microsoft 365 tenant-to-tenant
migration and administration, from a post-acquisition tenant consolidation.

Two things live here:

- **[`RUNBOOK.md`](RUNBOOK.md)** — the four-phase tenant-to-tenant migration runbook. The
  sequence, the reasoning, and what breaks when the order is wrong.
- **The supporting scripts** — Exchange, SharePoint, and endpoint tooling used to make the
  migration decisions and carry out the work.

Built against the Microsoft Graph API, PnP.PowerShell, ExchangeOnlineManagement,
MicrosoftTeams, and the SharePoint Online Management Shell.

---

## The migration runbook

**→ [Read the full runbook](RUNBOOK.md)**

Moving users between tenants is not a single operation. It is a sequence of permission
grants, coexistence changes, and source-side revocations that have to happen in the right
order, in batches, or users lose access to things they still need.

| Phase | Handles |
|---|---|
| **1 — Inventory and provisioning** | Enumerate existing access before changing anything, verify both identities, replicate SharePoint permissions and group membership onto the target account, handle Teams private channels separately, enable retained mail forwarding |
| **2 — Coexistence** | Repoint mail contacts at the target tenant, auto-reply on the source mailbox so senders learn the new address |
| **3 — Source decommissioning** | Restrict source mailbox client access, lock OneDrive, remove group and SharePoint permissions using the Phase 1 inventory — restrict access without deleting data |
| **4 — Teams and final lockdown** | Freeze team structure, demote owners, set backing SharePoint sites read-only, close out shared mailboxes |

The runbook covers the parts that are not obvious from the phase names: why the permission
inventory has to be generated before anything changes, why private channel membership is not
inherited from team membership, why every lockdown needs a matching unlock, and why
provisioning and revocation never run in the same pass.

> The migration implementation itself was client-specific and is not published here. The
> runbook documents the phase structure and operational reasoning, which is the transferable
> part.

---

## Scripts

### [`PowerShell/Exchange/`](PowerShell/Exchange/)

Exchange Online administration and reporting. The reporting scripts exist because migration
decisions need evidence — you cannot plan a cutover without knowing what is actually in the
tenant.

**Inventory and reporting**

- [`Get-MailboxInventory.ps1`](PowerShell/Exchange/Get-MailboxInventory.ps1) — tenant-wide
  mailbox report designed for large tenants. Bulk pre-loads Graph users, CAS settings, and
  licence SKUs into hashtables rather than making per-mailbox calls, which is what keeps the
  run inside a time-limited privileged access window. Includes inactive mailboxes, which are
  usually the ones a migration team most needs to see.
- [`Get-DomainSmtpReferences.ps1`](PowerShell/Exchange/Get-DomainSmtpReferences.ps1) — find
  every reference to a domain across mailbox addresses
- [`Get-MailboxForwardingRule.ps1`](PowerShell/Exchange/Get-MailboxForwardingRule.ps1),
  [`Get-MFAStatus.ps1`](PowerShell/Exchange/Get-MFAStatus.ps1),
  [`Get-GroupMembersToCSV.ps1`](PowerShell/Exchange/Get-GroupMembersToCSV.ps1)

**Message tracing**

- [`Get-MessageTrace.ps1`](PowerShell/Exchange/Get-MessageTrace.ps1),
  [`Get-MessageTrace-PastMonth-Detailed.ps1`](PowerShell/Exchange/Get-MessageTrace-PastMonth-Detailed.ps1)

**Shared mailboxes**

- [`New-SharedMailboxWithForwarding.ps1`](PowerShell/Exchange/New-SharedMailboxWithForwarding.ps1),
  [`Find-SharedMailboxes-RequireAuth.ps1`](PowerShell/Exchange/Find-SharedMailboxes-RequireAuth.ps1),
  [`Set-SharedMailboxes-RemoveAuthRequirement.ps1`](PowerShell/Exchange/Set-SharedMailboxes-RemoveAuthRequirement.ps1)

**Forwarding**

- [`Set-BulkEmailForwarding.ps1`](PowerShell/Exchange/Set-BulkEmailForwarding.ps1),
  [`Set-EmailForwarding-WithRetention.ps1`](PowerShell/Exchange/Set-EmailForwarding-WithRetention.ps1)

**Compliance**

- [`Get-LitigationHoldStatus.ps1`](PowerShell/Exchange/Get-LitigationHoldStatus.ps1),
  [`Invoke-ComplianceSearchPurge.ps1`](PowerShell/Exchange/Invoke-ComplianceSearchPurge.ps1),
  [`Invoke-DraftItemPurge.ps1`](PowerShell/Exchange/Invoke-DraftItemPurge.ps1)

### [`PowerShell/SharePoint/`](PowerShell/SharePoint/)

- [`Get-SpoSiteSizes-PnP.ps1`](PowerShell/SharePoint/Get-SpoSiteSizes-PnP.ps1) and
  [`Get-SpoSiteSizes-DeviceCode.ps1`](PowerShell/SharePoint/Get-SpoSiteSizes-DeviceCode.ps1) —
  site and OneDrive storage reporting, two authentication approaches for tenants where app
  consent is restricted
- [`Get-AllSitesWithEncryptedFiles.ps1`](PowerShell/SharePoint/Get-AllSitesWithEncryptedFiles.ps1) —
  locate encrypted files that will not migrate

### [`PowerShell/Windows/`](PowerShell/Windows/)

Endpoint configuration utilities — telemetry, privacy settings, bloatware removal.

---

## Related work

**[purview-ediscovery-export](https://github.com/AlanHardesty/purview-ediscovery-export)** —
end-to-end legal hold export via the Microsoft Graph eDiscovery API, built for the same
tenant decommission. Multi-hour resumable server-side collections, byte-range resumable
downloads, and a path for mailboxes whose owning accounts no longer exist.

A tenant consolidation has two halves: moving the people, and defensibly preserving what the
old tenant held before it is deleted. This repository is the first half; that one is the
second.

---

## Prerequisites

```powershell
Install-Module Microsoft.Graph
Install-Module PnP.PowerShell
Install-Module MicrosoftTeams
Install-Module ExchangeOnlineManagement
Install-Module Microsoft.Online.SharePoint.PowerShell
```

> **Run each script in its own PowerShell session.** ExchangeOnlineManagement,
> PnP.PowerShell, and MSAL.PS each ship their own incompatible copy of
> `Microsoft.Identity.Client.dll`. Once one is loaded into a process the others will fail to
> load.

## Configuration

Every script has a configuration block at the top. Replace the placeholder values before
running:

```powershell
$tenantName  = "contoso.onmicrosoft.com"
$adminUrl    = "https://contoso-admin.sharepoint.com"
$pnpClientId = "YOUR-PNP-CLIENT-ID"
```

## License

MIT — free to use, modify, and distribute.
