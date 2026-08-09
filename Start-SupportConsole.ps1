param([switch]$Once)

$ScriptRoot = Join-Path $PSScriptRoot "scripts"

function Clear-SupportConsole {
    # Clear-Host throws when output is redirected or the host has no valid
    # console buffer (for example CI, scheduled tasks, and remote runners).
    if ($Host.Name -ne "ConsoleHost" -or
        -not [Environment]::UserInteractive -or
        [Console]::IsOutputRedirected) {
        return
    }

    try {
        Clear-Host -ErrorAction Stop
    }
    catch {
        # Clearing is cosmetic and must never prevent diagnostics from running.
    }
}

$diagnostics = [ordered]@{
    "2"  = @{ Name = "PC Health";                    Script = "Get-PCHealth.ps1" }
    "3"  = @{ Name = "Network Health";               Script = "Get-NetworkHealth.ps1" }
    "4"  = @{ Name = "Event Health";                 Script = "Get-EventHealth.ps1" }
    "5"  = @{ Name = "Service Health";               Script = "Get-ServiceHealth.ps1" }
    "6"  = @{ Name = "Reboot State";                 Script = "Get-RebootHealth.ps1" }
    "7"  = @{ Name = "Software Health";               Script = "Get-SoftwareHealth.ps1" }
    "8"  = @{ Name = "Driver / Device Health";        Script = "Get-DriverHealth.ps1" }
    "9"  = @{ Name = "Windows Update Health";         Script = "Get-UpdateHealth.ps1" }
    "10" = @{ Name = "Security / BitLocker Health";   Script = "Get-SecurityHealth.ps1" }
}

function Get-StatusColor {
    param([string]$Status)

    switch ($Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        default { "Cyan" }
    }
}

function Write-HealthBar {
    param([object[]]$Snapshot)

    $passCount = @($Snapshot | Where-Object Status -eq "PASS").Count
    $infoCount = @($Snapshot | Where-Object Status -eq "INFO").Count
    $warnCount = @($Snapshot | Where-Object Status -eq "WARN").Count

    $score = [math]::Max(0, 100 - ($warnCount * 15) - ($infoCount * 5))
    Write-Host "Health  [" -NoNewline
    foreach ($item in $Snapshot) {
        Write-Host "#" -NoNewline -ForegroundColor (Get-StatusColor $item.Status)
    }
    Write-Host "]  " -NoNewline
    Write-Host "$passCount PASS" -NoNewline -ForegroundColor Green
    Write-Host "  $infoCount INFO" -NoNewline -ForegroundColor Cyan
    Write-Host "  $warnCount WARN" -NoNewline -ForegroundColor Yellow
    Write-Host "    TRIAGE SCORE $score/100" -ForegroundColor $(if ($score -ge 85) { "Green" } elseif ($score -ge 65) { "Yellow" } else { "Red" })
}

function Write-Gauge {
    param(
        [string]$Label,
        [double]$Percent,
        [string]$Suffix = ""
    )

    $value = [math]::Max(0, [math]::Min(100, [math]::Round($Percent)))
    $filled = [math]::Round($value / 10)
    $bar = ("█" * $filled) + ("░" * (10 - $filled))
    $color = if ($value -ge 90) { "Red" } elseif ($value -ge 75) { "Yellow" } else { "Green" }
    Write-Host ("{0,-7} [" -f $Label) -NoNewline -ForegroundColor DarkGray
    Write-Host $bar -NoNewline -ForegroundColor $color
    Write-Host ("] {0,3}% {1}" -f $value, $Suffix)
}

function Write-SystemGauges {
    param([object[]]$Snapshot)

    $pc = $Snapshot | Where-Object Id -eq 2 | Select-Object -First 1
    $events = $Snapshot | Where-Object Id -eq 4 | Select-Object -First 1
    if (-not $pc.Metrics.Count) { return }

    Write-Host ""
    Write-Host "LIVE SYSTEM PRESSURE" -ForegroundColor DarkCyan
    Write-Gauge "MEMORY" $pc.Metrics.MemoryUsedPercent "$($pc.Metrics.MemoryFreeGB) GB free"
    Write-Gauge "DISK C:" $pc.Metrics.DiskUsedPercent "$($pc.Metrics.DiskFreeGB) GB free"
    if ($events.Metrics.Count) {
        Write-Host ("EVENTS   {0} total  |  {1} patterns  |  {2} critical  |  {3} recurring" -f `
            $events.Metrics.Total, $events.Metrics.Patterns, $events.Metrics.Critical, $events.Metrics.RecurringPatterns)
    }
}

function Show-Dashboard {
    param(
        [object[]]$Snapshot,
        [string]$View = "MAIN MENU"
    )

    Clear-SupportConsole
    Write-Host "==========================================================================" -ForegroundColor DarkCyan
    Write-Host " ENDPOINT SUPPORT CONSOLE   $env:COMPUTERNAME   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor DarkCyan
    Write-Host " Snapshot collected in $script:snapshotSeconds s | Scores prioritize triage; they are not compliance ratings." -ForegroundColor DarkGray
    Write-HealthBar $Snapshot
    Write-SystemGauges $Snapshot
    Write-Host ""
    Write-Host ("{0,-3} {1,-10} {2,-6} {3}" -f "ID", "AREA", "STATE", "DETAIL") -ForegroundColor DarkGray
    Write-Host ("{0,-3} {1,-10} {2,-6} {3}" -f "--", "----------", "------", "------") -ForegroundColor DarkGray

    foreach ($item in $Snapshot) {
        Write-Host ("{0,-3} {1,-10} " -f $item.Id, $item.Area) -NoNewline
        Write-Host ("{0,-6}" -f $item.Status) -NoNewline -ForegroundColor (Get-StatusColor $item.Status)
        Write-Host " $($item.Detail)"
    }

    $attention = @($Snapshot | Where-Object Status -ne "PASS" | Sort-Object @{ Expression = { if ($_.Status -eq "WARN") { 0 } else { 1 } } })
    if ($attention.Count) {
        Write-Host ""
        Write-Host "PRIORITY QUEUE  " -NoNewline -ForegroundColor DarkCyan
        Write-Host (($attention | ForEach-Object { "$($_.Id) $($_.Area) [$($_.Status)]" }) -join "  ->  ")
    }

    Write-Host ""
    Write-Host "--- $View ---------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Show-Menu {
    Write-Host "Select a numbered fault domain to investigate it." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  1   Refresh dashboard"
    foreach ($entry in $diagnostics.GetEnumerator()) {
        Write-Host ("  {0,-3} {1}" -f $entry.Key, $entry.Value.Name)
    }
    Write-Host ""
    Write-Host "  Q   Quit"
    Write-Host ""
}

Clear-SupportConsole
Write-Host "Collecting endpoint health data..." -ForegroundColor Cyan
$collectionWatch = [System.Diagnostics.Stopwatch]::StartNew()
$snapshot = @(& "$ScriptRoot\Get-SupportSnapshot.ps1" -PassThru)
$collectionWatch.Stop()
$script:snapshotSeconds = [math]::Round($collectionWatch.Elapsed.TotalSeconds, 1)
$choice = ""

if ($Once) {
    Show-Dashboard -Snapshot $snapshot -View "SNAPSHOT ONLY"
    return
}

do {
    Show-Dashboard -Snapshot $snapshot
    Show-Menu
    $choice = (Read-Host "support").Trim().ToUpperInvariant()

    if ($choice -eq "1") {
        Show-Dashboard -Snapshot $snapshot -View "REFRESHING DASHBOARD"
        Write-Host "Collecting fresh endpoint health data..." -ForegroundColor Cyan
        $collectionWatch.Restart()
        $snapshot = @(& "$ScriptRoot\Get-SupportSnapshot.ps1" -PassThru)
        $collectionWatch.Stop()
        $script:snapshotSeconds = [math]::Round($collectionWatch.Elapsed.TotalSeconds, 1)
        continue
    }

    if ($diagnostics.Contains($choice)) {
        $selected = $diagnostics[$choice]
        Show-Dashboard -Snapshot $snapshot -View $selected.Name.ToUpperInvariant()
        & (Join-Path $ScriptRoot $selected.Script)
        Write-Host ""
        [void](Read-Host "Press Enter to return to the dashboard")
        continue
    }

    if ($choice -ne "Q") {
        Show-Dashboard -Snapshot $snapshot -View "INPUT HELP"
        Write-Host "'$choice' is not a valid selection." -ForegroundColor Yellow
        Write-Host "Choose 1-10, or Q to quit."
        Start-Sleep -Seconds 2
    }
} until ($choice -eq "Q")

Clear-SupportConsole
Write-Host "Support console closed." -ForegroundColor Cyan
