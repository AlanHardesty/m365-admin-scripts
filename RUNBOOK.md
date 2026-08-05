# Tenant-to-Tenant Migration Runbook

A phased runbook for moving users between Microsoft 365 tenants during a post-acquisition
consolidation. This describes the **sequence and the reasoning** — what happens in each
phase, why it happens in that order, and what breaks when it doesn't.

It is written from executing all four phases against an enterprise tenant, in batches, over
the course of a consolidation programme. The implementation details are environment-specific
and belong to the client; the structure is transferable, and the structure is the part that
takes a migration to learn.

---

## The operating model

**Users move in batches, not all at once.** Each batch is a CSV. Every phase runs against
that CSV, and a batch progresses through all four phases before the next one starts. This
matters because it bounds the blast radius: a mistake affects ten users, not ten thousand.

**Three identities are in play per user:**

| | |
|---|---|
| Source UPN | The user's account in the tenant being decommissioned |
| Target UPN | The target tenant's account, present as a **guest** in the source tenant |
| Target email | The user's real address in the target tenant |

The guest account is the mechanism that makes the whole thing work. During the migration the
target identity holds real permissions in the source tenant, so a user can be working from
their new account while their old data still lives in the old tenant.

**Provisioning and revocation are never in the same pass.** Access is granted to the target,
verified, and only then removed from the source. Doing both in one operation means a failure
halfway through leaves a user with access to neither tenant.

---

## Phase 1 — Inventory and provisioning

*Goal: the target account can do everything the source account could.*

**What this phase handles:**

- **Permission inventory.** Enumerate every SharePoint permission the source user holds,
  across every site, and write it to a report. This happens *first*, before anything is
  changed.
- **Account verification.** Confirm both the source account and the target guest account
  resolve before touching anything. A typo in a batch CSV should fail here, cheaply, not
  three phases later.
- **SharePoint permission replication.** Grant the target account equivalent access to
  everything the inventory found.
- **Group membership.** Add the target account to every Microsoft 365 group the source user
  belongs to.
- **Teams private channels.** Handled separately, because **private channel membership is not
  inherited from team membership.** Adding the target account to a team does not put it in
  that team's private channels. This is the single most common thing to miss, and it surfaces
  as a user complaint weeks later when they go looking for a channel that is no longer there.
- **Mail forwarding.** Turn on forwarding from the source mailbox to the target tenant, with
  a copy retained in the source mailbox. Retention matters — a forward that does not keep a
  copy silently empties the mailbox you may later need to export.

**Why inventory has to come first:** the permission report generated here is the input to the
revocation step in Phase 3. Without a record of what was granted, removing source access
later is guesswork, and guesswork on permission removal is how you break a site nobody
noticed was shared.

---

## Phase 2 — Coexistence

*Goal: mail addressed to either tenant reaches the user, and senders learn the new address.*

This is the window where the user is working in the target tenant but the world still has
their old address. It is short, but it is where user-visible failures happen.

**What this phase handles:**

- **Mail contact redirection.** Repoint mail contacts and distribution list members at the
  target tenant address, so internal mail stops routing through the old mailbox.
- **Auto-reply on the source mailbox.** Tell senders where the user actually is. This is the
  cheapest possible reduction in support load — without it, every external correspondent
  keeps mailing an address that forwards silently, and nobody updates their address book.

**The forwarding set up in Phase 1 is what makes this phase safe.** Mail continues to arrive
and continues to be retained while the address change propagates.

---

## Phase 3 — Source decommissioning

*Goal: the source account can no longer be used, while the source data stays intact.*

The distinction that matters here: **restricting access is not the same as deleting data.**
Everything in this phase locks the source account out while leaving mailboxes, OneDrive
content, and site data exactly where they are — which is what makes the tenant safely
deletable later, and what keeps legal hold obligations satisfiable.

**What this phase handles:**

- **Mailbox client access restriction.** Disable the client protocols on the source mailbox.
  The mailbox continues to receive mail and continues to forward — nobody can sign into it.
  This is deliberately not a mailbox deletion or a licence removal.
- **OneDrive lockdown.** Set the source OneDrive to no-access.
- **Group membership removal.** Remove the source user from Microsoft 365 groups, now that
  the target account is a member.
- **SharePoint permission removal**, driven by the Phase 1 inventory report — the reason that
  report was generated before anything changed.
- **Directory group membership.** On-premises AD group updates where hybrid identity is in
  play.

**Every lock has an unlock.** The OneDrive restriction has a matching re-enable operation,
and it gets used more than you would expect. Someone always needs one more file after
cutover. A migration that cannot reverse a lockdown cleanly generates escalations; one that
can absorbs them quietly.

---

## Phase 4 — Teams and final lockdown

*Goal: teams are frozen in a known state and shared resources are closed out.*

Teams is last because it migrates differently from mail and files. A team is not one object —
it is a group, a set of channels, a set of private channels with their own membership, and a
backing SharePoint site. Freezing it means handling all of those.

**What this phase handles:**

- **Stop the target state moving.** Disable private channel creation so the structure being
  migrated stops changing underneath the migration.
- **Ownership and read-only.** Demote team owners and set the backing SharePoint sites to
  read-only, so an archived team cannot be modified after it has been captured.
- **Shared mailboxes.** Disable client access and strip delegate permissions. Shared
  mailboxes are consistently the last thing anyone thinks about and the first thing someone
  complains about — they have no owner to consult, permissions accumulate over years, and
  nobody can tell you who still needs them.

**Site collection administration caveat:** setting a public archived team's SharePoint site
to read-only requires the operating admin account to be added as a site collection admin
first, and removed afterwards. It is not granted by tenant-level roles.

---

## Cross-cutting constraints

**One PowerShell session per tool.** `ExchangeOnlineManagement`, `PnP.PowerShell`, and
`MSAL.PS` each ship their own incompatible copy of `Microsoft.Identity.Client.dll`. Once one
is loaded into a process the others cannot load in it. Any workflow touching both Exchange
and SharePoint has to be split into separate scripts handing off through a file on disk.
This is a constraint to design around, not a bug to fix.

**Elevated access is time-limited.** Where privileged roles are activated just-in-time,
every long-running operation must complete inside the activation window or be resumable
across one. This is a real design constraint on tenant-wide reporting, not an afterthought —
it shapes how data is retrieved, because a per-object API call multiplied across a large
tenant will not finish in time.

**Reporting is part of the migration, not separate from it.** Cutover decisions need evidence:
which mailboxes are actually in use, which are forwarding and where, which are on hold, which
shared mailboxes still have delegates. The reporting scripts in this repository exist because
those questions came up repeatedly and had to be answered from data rather than assumption.

**Everything is re-runnable.** Batches get interrupted, rows get retried, and a phase gets
re-run against a CSV that is half-complete. Every operation checks current state before acting.

---

## What the phases look like end to end

```
Phase 1   Inventory  →  Verify  →  Grant target access  →  Enable forwarding
                                                                  │
Phase 2                              Redirect contacts  ←─────────┘
                                     Auto-reply on source
                                                │
Phase 3            Restrict source mailbox  ←───┘
                   Lock OneDrive
                   Remove source permissions (using the Phase 1 inventory)
                                                │
Phase 4                     Freeze Teams  ←─────┘
                            Read-only SharePoint
                            Close out shared mailboxes
```

Nothing in Phase 3 runs until the Phase 1 grants are confirmed working. Nothing in Phase 4
runs until the users of those teams have moved.

---

## Related

For the compliance side of a tenant decommission — exporting legal hold data before the
tenant is deleted — see
[purview-ediscovery-export](https://github.com/AlanHardesty/purview-ediscovery-export).
