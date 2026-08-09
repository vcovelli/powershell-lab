# PowerShell Endpoint Support Console

Version 1.0.0

A local, read-only Windows diagnostic console for endpoint support practice and fast fault-domain triage.

The tool answers three questions:

1. What does Windows see right now?
2. Which subsystem deserves attention?
3. What evidence should the technician inspect next?

It automates the search for evidence—not the final judgment or remediation.

## Quick start

Open PowerShell in this folder and run:

```powershell
.\Start-SupportConsole.ps1
```

If your PowerShell profile already defines the project shortcut, run:

```powershell
support
```

The initial snapshot can take several seconds because Windows management providers must answer live queries. Once loaded, the dashboard remains at the top while the menu and drill-down content change below it.

## Normal support workflow

1. Read the dashboard and its priority queue.
2. Treat `WARN` as a reason to investigate—not proof of root cause.
3. Choose the matching menu number for deeper evidence.
4. Correlate the evidence with the user's symptom and its timeline.
5. Refresh with option `1` after the system state changes.

For a step-by-step example, see [Operator Guide](docs/OPERATOR-GUIDE.md).

## Dashboard states

| State | Meaning | Technician response |
|---|---|---|
| `PASS` | The quick check found no obvious fault evidence. | Move on unless the symptom points here. |
| `INFO` | A notable state exists, but it is not automatically unhealthy. | Use context and the user's symptoms. |
| `WARN` | Evidence crossed a triage threshold or a current check failed. | Open the suggested drill-down. |

The triage score is a navigation aid. It is not a compliance score, security grade, SLA measurement, or proof that the endpoint is healthy.

## Menu

| Option | Area | Primary question |
|---:|---|---|
| 1 | Refresh dashboard | Has the current state changed? |
| 2 | PC Health | Is the endpoint under resource or storage pressure? |
| 3 | Network Health | Where does connectivity fail: adapter, gateway, DNS, or HTTPS? |
| 4 | Event Health | Which errors are recent, repeated, and relevant? |
| 5 | Service Health | Are expected-running core services stopped? |
| 6 | Reboot State | Is Windows waiting for a restart to finish work? |
| 7 | Software Health | Is an application installed, and which version is present? |
| 8 | Driver / Device Health | Does Device Manager have real problem codes? |
| 9 | Windows Update Health | Are failures current, historical, or followed by success? |
| 10 | Security / BitLocker Health | What do Defender, firewall, BitLocker, Secure Boot, and TPM report? |

Detailed interpretation and false positives are documented in [Diagnostic Reference](docs/DIAGNOSTIC-REFERENCE.md).

## Useful direct commands

```powershell
# Render one dashboard without opening the menu
.\Start-SupportConsole.ps1 -Once

# Show the top 15 event patterns from the last 48 hours
.\scripts\Get-EventHealth.ps1 -Hours 48 -Top 15

# Read full messages for one provider and event ID
.\scripts\Get-EventDetails.ps1 -Provider 'Universal Print' -EventId 1 -Hours 24

# Search installed applications
.\scripts\Get-SoftwareHealth.ps1 -Name 'Teams'

# Explicitly request slower, complete inventories
.\scripts\Get-SoftwareHealth.ps1 -All
.\scripts\Get-DriverHealth.ps1 -IncludeInventory

# Validate every PowerShell script's syntax
.\tests\Test-Syntax.ps1

# Run the complete validation suite (includes live Windows checks)
.\tests\Test-All.ps1
```

## Safety boundaries

The project is diagnostic-first and read-only. It does not:

- reboot the computer;
- install or uninstall software, drivers, or updates;
- reset networking or modify VPN configuration;
- change registry values, firewall rules, Defender, or BitLocker;
- change users, groups, domains, AD, Intune, or ConfigMgr;
- query multiple endpoints or perform fleet-wide actions.

No credentials, secrets, or BitLocker recovery keys should be added to output or reports.

## Documentation map

- [Operator Guide](docs/OPERATOR-GUIDE.md) — how to work an incident with the console.
- [Diagnostic Reference](docs/DIAGNOSTIC-REFERENCE.md) — what each check means and common false positives.
- [Architecture and Testing](docs/ARCHITECTURE.md) — project structure, data flow, extension rules, and validation.
- [Release and Workplace Checklist](docs/RELEASE-CHECKLIST.md) — approval, data-handling, compatibility, and packaging checks.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7 with Windows management cmdlets available
- Local access to the endpoint being diagnosed
- Administrator rights are helpful for some security and device queries, but the console handles unavailable data as informational where possible
