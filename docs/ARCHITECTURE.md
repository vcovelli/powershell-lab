# Architecture and Testing

## Design model

The project separates fast triage from deep evidence collection:

```text
Start-SupportConsole.ps1
        |
        +-- Get-SupportSnapshot.ps1    fast checks for areas 2-10
        |
        +-- menu option 2-10           one detailed subsystem script
```

The snapshot answers **where should I look?** Detailed scripts answer **what evidence does Windows have for this subsystem?**

## Project layout

```text
powershell-lab/
├── Start-SupportConsole.ps1
├── README.md
├── docs/
│   ├── OPERATOR-GUIDE.md
│   ├── DIAGNOSTIC-REFERENCE.md
│   └── ARCHITECTURE.md
├── scripts/
│   ├── Get-SupportSnapshot.ps1
│   ├── Get-PCHealth.ps1
│   ├── Get-NetworkHealth.ps1
│   ├── Get-EventHealth.ps1
│   ├── Get-EventDetails.ps1
│   ├── Get-ServiceHealth.ps1
│   ├── Get-RebootHealth.ps1
│   ├── Get-SoftwareHealth.ps1
│   ├── Get-DriverHealth.ps1
│   ├── Get-UpdateHealth.ps1
│   └── Get-SecurityHealth.ps1
└── tests/
    └── Test-Syntax.ps1
```

## Snapshot contract

`Get-SupportSnapshot.ps1 -PassThru` returns nine objects, one for menu IDs 2-10. Each object contains:

- `Id` — matching drill-down menu number;
- `Area` — short subsystem name;
- `Status` — PASS, INFO, or WARN;
- `Detail` — concise technician-facing evidence;
- `Metrics` — structured values used by dashboard gauges and statistics.

Do not replace these objects with formatted strings. Formatting belongs at the console presentation boundary.

## Performance rules

- Quick checks must be bounded and concise.
- Slow full inventories must be opt-in.
- Network probes require explicit short timeouts.
- Do not call all detailed scripts from the snapshot.
- Query a Windows provider once and reuse the results when possible.
- Avoid `Win32_Product`.

## Assessment rules

- `PASS`: no obvious evidence found by the defined check.
- `INFO`: state is noteworthy but may be normal.
- `WARN`: current failure evidence or a meaningful threshold warrants drill-down.
- Unavailable data should normally be INFO unless the inability to query is itself operationally significant.
- Historical logs must be correlated with current functional tests.

## Validation

Run the syntax suite after every edit:

```powershell
.\tests\Test-Syntax.ps1
```

Run all syntax, live snapshot-contract, and non-interactive rendering checks:

```powershell
.\tests\Test-All.ps1
```

Verify the snapshot contract:

```powershell
$snapshot = @(.\scripts\Get-SupportSnapshot.ps1 -PassThru)
$snapshot.Count
$snapshot | Format-Table Id, Area, Status, Detail
```

Expected row count: `9`.

Render the dashboard without entering an interactive loop:

```powershell
.\Start-SupportConsole.ps1 -Once
```

Run modified drill-down scripts directly and confirm that they make no state changes.

## Extension checklist

Before adding a new check:

1. Identify the Windows subsystem and authoritative data source.
2. Decide whether it belongs in the fast snapshot or a drill-down.
3. Define PASS, INFO, WARN, and unavailable behavior.
4. Document likely false positives.
5. Keep the operation read-only.
6. Return structured objects before formatting.
7. Add or update validation.
