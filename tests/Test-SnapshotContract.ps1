$projectRoot = Split-Path $PSScriptRoot -Parent
$snapshotScript = Join-Path $projectRoot "scripts\Get-SupportSnapshot.ps1"
$failures = @()
$snapshotErrors = @()

$snapshot = @(& $snapshotScript -PassThru -ErrorVariable +snapshotErrors)

if ($snapshotErrors.Count) {
    $failures += "Snapshot emitted $($snapshotErrors.Count) PowerShell error(s)."
}

if ($snapshot.Count -ne 9) {
    $failures += "Expected 9 snapshot rows; received $($snapshot.Count)."
}

$expectedIds = 2..10
$actualIds = @($snapshot | ForEach-Object Id | Sort-Object)
if (($actualIds -join ",") -ne ($expectedIds -join ",")) {
    $failures += "Expected IDs 2-10 exactly once; received $($actualIds -join ', ')."
}

foreach ($item in $snapshot) {
    foreach ($property in "Id", "Area", "Status", "Detail", "Metrics") {
        if (-not $item.PSObject.Properties[$property]) {
            $failures += "Snapshot row $($item.Id) is missing property '$property'."
        }
    }

    if ($item.Status -notin "PASS", "INFO", "WARN") {
        $failures += "Snapshot row $($item.Id) has invalid status '$($item.Status)'."
    }

    if ([string]::IsNullOrWhiteSpace([string]$item.Area) -or
        [string]::IsNullOrWhiteSpace([string]$item.Detail)) {
        $failures += "Snapshot row $($item.Id) has an empty Area or Detail."
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "[PASS] Snapshot returned the expected 9-row contract without errors."
