# M365 Admin Scripts

A collection of PowerShell scripts for Microsoft 365 administration, automation, and governance. Built for real-world enterprise environments using the Microsoft Graph API, PnP.PowerShell, ExchangeOnlineManagement, and MicrosoftTeams modules.

## Contents

### [PowerShell/Migration/](PowerShell/Migration/)
A numbered, sequenced workflow for migrating users from one M365 tenant to another. Covers SharePoint permissions, Office 365 group membership, Teams private channels, mailbox access, OneDrive lock states, and post-migration cleanup.

### [PowerShell/Exchange/](PowerShell/Exchange/)
Scripts for Exchange Online and mailbox administration — forwarding rules, message tracing, shared mailbox management, CAS mailbox settings, and compliance search.

### [PowerShell/SharePoint/](PowerShell/SharePoint/)
Scripts for SharePoint Online site management — site size reporting, permission inventories, encrypted file detection, and SPO configuration.

### [PowerShell/Windows/](PowerShell/Windows/)
General Windows administration scripts — telemetry management, privacy settings, bloatware removal, and system utilities.

## Prerequisites

Scripts use a mix of the following modules depending on the task:

```powershell
Install-Module Microsoft.Graph
Install-Module PnP.PowerShell
Install-Module MicrosoftTeams
Install-Module ExchangeOnlineManagement
Install-Module Microsoft.Online.SharePoint.PowerShell
```

## Usage

Each script contains a `# ---- CONFIGURATION ----` section at the top with variables to update before running. Replace all placeholder values (`contoso.onmicrosoft.com`, `YOUR-PNP-CLIENT-ID`, etc.) with your environment's values.

## License

MIT License — free to use, modify, and distribute.
