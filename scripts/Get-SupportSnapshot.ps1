param(
    [switch]$PassThru
)

$ErrorActionPreference = "SilentlyContinue"

function New-SnapshotResult {
    param(
        [int]$Id,
        [string]$Area,
        [ValidateSet("PASS", "INFO", "WARN")]
        [string]$Status,
        [string]$Detail,
        [hashtable]$Metrics = @{}
    )

    [PSCustomObject]@{
        Id     = $Id
        Area   = $Area
        Status = $Status
        Detail = $Detail
        Metrics = $Metrics
    }
}

function Test-PendingReboot {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )

    if ($paths | Where-Object { Test-Path $_ }) {
        return $true
    }

    $renameOperations = Get-ItemProperty `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations

    return [bool]$renameOperations.PendingFileRenameOperations
}

$results = @()

# 2 - PC: query only the few CIM properties needed for triage.
$computer = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

if ($computer -and $os -and $disk) {
    $ramGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    $freeRamGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $memoryUsedPercent = [math]::Round((1 - (($os.FreePhysicalMemory * 1KB) / $computer.TotalPhysicalMemory)) * 100)
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
    $diskUsedPercent = [math]::Round((1 - ($disk.FreeSpace / $disk.Size)) * 100)
    $uptimeDays = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
    $pcStatus = if ($freeGB -lt 20 -or $uptimeDays -gt 14) { "WARN" } else { "PASS" }
    $results += New-SnapshotResult 2 "PC" $pcStatus "$ramGB GB RAM | $freeGB GB free | $uptimeDays d uptime" @{
        MemoryUsedPercent = $memoryUsedPercent; MemoryFreeGB = $freeRamGB
        DiskUsedPercent = $diskUsedPercent; DiskFreeGB = $freeGB; UptimeDays = $uptimeDays
    }
}
else {
    $results += New-SnapshotResult 2 "PC" "INFO" "Core system information unavailable"
}

# 3 - Network: assess the default-route path, not every virtual/VPN adapter.
$route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
    Sort-Object RouteMetric |
    Select-Object -First 1
$ipConfig = if ($route) { Get-NetIPConfiguration -InterfaceIndex $route.InterfaceIndex }
$gateway = $ipConfig.IPv4DefaultGateway.NextHop
$gatewayMs = $null
$gatewayOK = $false
if ($gateway) {
    try {
        $ping = [System.Net.NetworkInformation.Ping]::new()
        $reply = $ping.Send($gateway, 1000)
        $gatewayOK = $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success
        if ($gatewayOK) { $gatewayMs = $reply.RoundtripTime }
        $ping.Dispose()
    }
    catch { $gatewayOK = $false }
}

$dnsWatch = [System.Diagnostics.Stopwatch]::StartNew()
$dnsOK = [bool](Resolve-DnsName microsoft.com)
$dnsWatch.Stop()
$dnsMs = $dnsWatch.ElapsedMilliseconds

$httpsWatch = [System.Diagnostics.Stopwatch]::StartNew()
$httpsOK = $false
$tcpClient = [System.Net.Sockets.TcpClient]::new()
try {
    $connect = $tcpClient.BeginConnect("microsoft.com", 443, $null, $null)
    if ($connect.AsyncWaitHandle.WaitOne(1500)) {
        $tcpClient.EndConnect($connect)
        $httpsOK = $tcpClient.Connected
    }
}
catch { $httpsOK = $false }
finally { $tcpClient.Dispose(); $httpsWatch.Stop() }
$httpsMs = $httpsWatch.ElapsedMilliseconds
$networkFailures = @($gatewayOK, $dnsOK, $httpsOK) | Where-Object { $_ -eq $false }

if (-not $route) {
    $results += New-SnapshotResult 3 "Network" "WARN" "No IPv4 default route detected"
}
elseif ($networkFailures.Count -gt 0) {
    $failedNames = @()
    if (-not $gatewayOK) { $failedNames += "gateway" }
    if (-not $dnsOK) { $failedNames += "DNS" }
    if (-not $httpsOK) { $failedNames += "HTTPS" }
    $results += New-SnapshotResult 3 "Network" "WARN" "Failed: $($failedNames -join ', ') on $($ipConfig.InterfaceAlias)"
}
else {
    $results += New-SnapshotResult 3 "Network" "PASS" "Gateway ${gatewayMs}ms | DNS ${dnsMs}ms | HTTPS ${httpsMs}ms via $($ipConfig.InterfaceAlias)" @{
        GatewayMs = $gatewayMs; DnsMs = $dnsMs; HttpsMs = $httpsMs
    }
}

# 4 - Events: volume is a signal for drill-down, not proof of one active fault.
$events = @(Get-WinEvent -FilterHashtable @{
    LogName = "System", "Application"
    Level = 1, 2
    StartTime = (Get-Date).AddHours(-24)
})
$eventGroups = @($events | Group-Object ProviderName, Id)
$hasCriticalEvent = [bool]($events | Where-Object Level -eq 1 | Select-Object -First 1)
$hasRecurringEvent = [bool]($eventGroups | Where-Object Count -ge 10 | Select-Object -First 1)
$eventStatus = if ($hasCriticalEvent -or $hasRecurringEvent) { "WARN" } elseif ($events.Count -gt 0) { "INFO" } else { "PASS" }
$eventDetail = if ($events.Count) { "$($events.Count) Critical/Error events in last 24h" } else { "No Critical/Error events in last 24h" }
$results += New-SnapshotResult 4 "Events" $eventStatus $eventDetail @{
    Total = $events.Count; Patterns = $eventGroups.Count
    Critical = @($events | Where-Object Level -eq 1).Count
    RecurringPatterns = @($eventGroups | Where-Object Count -ge 10).Count
}

# 5 - Services: on-demand update services are intentionally excluded.
$requiredServices = "Spooler", "Winmgmt", "Dnscache", "LanmanWorkstation"
$stoppedServices = @($requiredServices | Where-Object {
    (Get-Service -Name $_).Status -ne "Running"
})
if ($stoppedServices.Count) {
    $results += New-SnapshotResult 5 "Services" "WARN" "Unexpectedly stopped: $($stoppedServices -join ', ')"
}
else {
    $results += New-SnapshotResult 5 "Services" "PASS" "Core expected-running services are running"
}

# 6 - Reboot: informational because the script never initiates a reboot.
$rebootPending = Test-PendingReboot
if ($rebootPending) {
    $results += New-SnapshotResult 6 "Reboot" "INFO" "Pending reboot detected"
}
else {
    $results += New-SnapshotResult 6 "Reboot" "PASS" "No common pending reboot indicators"
}

# 7 - Software: verify that registry inventory can be read without dumping it.
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$softwareCount = @(Get-ItemProperty -Path $uninstallPaths | Where-Object DisplayName).Count
if ($softwareCount) {
    $results += New-SnapshotResult 7 "Software" "PASS" "$softwareCount installed application entries available"
}
else {
    $results += New-SnapshotResult 7 "Software" "WARN" "No installed application entries discovered"
}

# 8 - Devices: ConfigManagerErrorCode is the Device Manager problem code.
$problemDevices = @(Get-CimInstance Win32_PnPEntity -Filter "ConfigManagerErrorCode <> 0" |
    Where-Object { $_.Present -ne $false })
if ($problemDevices.Count) {
    $results += New-SnapshotResult 8 "Devices" "WARN" "$($problemDevices.Count) present device(s) have problem codes" @{ ProblemCount = $problemDevices.Count }
}
else {
    $results += New-SnapshotResult 8 "Devices" "PASS" "No present devices with problem codes" @{ ProblemCount = 0 }
}

# 9 - Updates: a pending reboot is INFO; recent failure events are WARN.
$updateErrors = @(Get-WinEvent -FilterHashtable @{
    LogName = "System"
    ProviderName = "Microsoft-Windows-WindowsUpdateClient"
    Level = 2
    StartTime = (Get-Date).AddDays(-7)
})
$latestUpdate = Get-HotFix | Where-Object InstalledOn | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($updateErrors.Count) {
    $results += New-SnapshotResult 9 "Updates" "WARN" "$($updateErrors.Count) failure event(s) in 7d; inspect update history"
}
elseif ($rebootPending) {
    $results += New-SnapshotResult 9 "Updates" "INFO" "No recent failure events; reboot pending"
}
elseif ($latestUpdate) {
    $results += New-SnapshotResult 9 "Updates" "PASS" "No recent failures; latest $($latestUpdate.HotFixID) on $($latestUpdate.InstalledOn.ToString('yyyy-MM-dd'))"
}
else {
    $results += New-SnapshotResult 9 "Updates" "INFO" "No recent failures; installed-update history unavailable"
}

# 10 - Security: fast dashboard evidence; option 10 performs the deep provider queries.
$registeredAntivirus = @(Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntivirusProduct)
$firewallService = Get-Service -Name MpsSvc
$securityWarnings = @()
if (-not $registeredAntivirus.Count) { $securityWarnings += "no antivirus registered" }
if ($firewallService -and $firewallService.Status -ne "Running") { $securityWarnings += "firewall service not running" }
if ($securityWarnings.Count) {
    $results += New-SnapshotResult 10 "Security" "WARN" ($securityWarnings -join "; ")
}
elseif (-not $firewallService) {
    $results += New-SnapshotResult 10 "Security" "INFO" "Quick security state unavailable; use option 10"
}
else {
    $avNames = @($registeredAntivirus | ForEach-Object displayName | Sort-Object -Unique) -join ", "
    $results += New-SnapshotResult 10 "Security" "PASS" "AV registered: $avNames | Firewall service running"
}

if ($PassThru) {
    return $results
}

Write-Host ""
Write-Host "========================================"
Write-Host "       QUICK SUPPORT SNAPSHOT"
Write-Host "========================================"
$results | Format-Table Id, Area, Status, Detail -AutoSize -Wrap

$drillDowns = @($results | Where-Object Status -ne "PASS")
if ($drillDowns.Count) {
    Write-Host "SUGGESTED DRILL-DOWNS"
    foreach ($result in $drillDowns) {
        Write-Host "-> $($result.Id) - $($result.Area) Health"
    }
}
else {
    Write-Host "No immediate drill-downs suggested."
}
