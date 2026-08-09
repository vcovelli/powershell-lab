Write-Host ""
Write-Host "=== SERVICE HEALTH ==="

$serviceChecks = @(
    @{ Name = "Spooler";            Expected = "Running"; Note = "Printing" }
    @{ Name = "Winmgmt";            Expected = "Running"; Note = "WMI/CIM management" }
    @{ Name = "Dnscache";           Expected = "Running"; Note = "DNS client" }
    @{ Name = "LanmanWorkstation";  Expected = "Running"; Note = "SMB/workstation service" }

    # These may legitimately be stopped when idle
    @{ Name = "BITS";               Expected = "OnDemand"; Note = "Background transfers" }
    @{ Name = "wuauserv";           Expected = "OnDemand"; Note = "Windows Update" }
)

# One CIM query supplies startup configuration for every checked service.
$serviceConfigurations = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue)

$results = foreach ($check in $serviceChecks) {

    $svc = Get-Service -Name $check.Name -ErrorAction SilentlyContinue
    $serviceConfig = $serviceConfigurations |
        Where-Object Name -eq $check.Name |
        Select-Object -First 1

    if (-not $svc) {
        [PSCustomObject]@{
            Service  = $check.Name
            Status   = "Missing"
            Expected = $check.Expected
            StartType = "Unknown"
            Note     = $check.Note
            Health   = "INFO"
        }

        continue
    }

    $health = "PASS"

    if ($check.Expected -eq "Running" -and $svc.Status -ne "Running") {
        $health = "WARN"
    }

    [PSCustomObject]@{
        Service  = $svc.Name
        Status   = $svc.Status
        Expected = $check.Expected
        StartType = $serviceConfig.StartMode
        Note     = $check.Note
        Health   = $health
    }
}

$results | Format-Table -AutoSize

Write-Host ""
Write-Host "=== SERVICE ASSESSMENT ==="

$warnings = $results | Where-Object Health -eq "WARN"

if ($warnings) {
    foreach ($warning in $warnings) {
        Write-Host "[WARN] $($warning.Service) is $($warning.Status) but expected Running."
    }
}
else {
    Write-Host "[PASS] No unexpectedly stopped core services detected."
}
