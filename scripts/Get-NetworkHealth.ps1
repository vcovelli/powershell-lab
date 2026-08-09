Write-Host ""
Write-Host "=== NETWORK HEALTH ==="

# ------------------------------------------------------------
# PRIMARY ROUTE / ACTIVE INTERFACE
# ------------------------------------------------------------

$defaultRoute = Get-NetRoute `
    -DestinationPrefix "0.0.0.0/0" `
    -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric |
    Select-Object -First 1

$primaryAdapter = $null

if ($defaultRoute) {
    $primaryAdapter = Get-NetIPConfiguration `
        -InterfaceIndex $defaultRoute.InterfaceIndex `
        -ErrorAction SilentlyContinue
}

if ($primaryAdapter) {

    [PSCustomObject]@{
        Interface = $primaryAdapter.InterfaceAlias
        IPv4      = $primaryAdapter.IPv4Address.IPAddress
        Gateway   = $primaryAdapter.IPv4DefaultGateway.NextHop
        DNS       = $primaryAdapter.DNSServer.ServerAddresses -join ", "
        Status    = "Active"
    } | Format-List

}
else {
    Write-Host "[WARN] No IPv4 default route detected."
}

# ------------------------------------------------------------
# ADAPTER INVENTORY
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== NETWORK ADAPTERS ==="

$adapters = Get-NetAdapter -ErrorAction SilentlyContinue

$adapterResults = foreach ($adapter in $adapters) {

    $type = "Physical"

    if (
        $adapter.Name -match "Tailscale" -or
        $adapter.InterfaceDescription -match "Tailscale"
    ) {
        $type = "Overlay/VPN"
    }
    elseif (
        $adapter.Name -match "Proton|VPN|TAP" -or
        $adapter.InterfaceDescription -match "Proton|VPN|TAP"
    ) {
        $type = "VPN"
    }
    elseif (
        $adapter.Name -match "vEthernet|WSL|Hyper-V" -or
        $adapter.InterfaceDescription -match "Hyper-V|Virtual"
    ) {
        $type = "Virtual"
    }

    [PSCustomObject]@{
        Name      = $adapter.Name
        Type      = $type
        Status    = $adapter.Status
        LinkSpeed = $adapter.LinkSpeed
    }
}

$adapterResults | Format-Table -AutoSize

# ------------------------------------------------------------
# CONNECTIVITY TESTS
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== CONNECTIVITY TESTS ==="

$results = @()

$gateway = $null

if ($primaryAdapter -and $primaryAdapter.IPv4DefaultGateway) {
    $gateway = $primaryAdapter.IPv4DefaultGateway.NextHop
}

if ($gateway) {

    $gatewayResult = Test-Connection `
        -ComputerName $gateway `
        -Count 1 `
        -Quiet `
        -ErrorAction SilentlyContinue

    $results += [PSCustomObject]@{
        Test   = "Gateway"
        Target = $gateway
        Result = $gatewayResult
    }
}

$internetResult = Test-Connection `
    -ComputerName "1.1.1.1" `
    -Count 1 `
    -Quiet `
    -ErrorAction SilentlyContinue

$results += [PSCustomObject]@{
    Test   = "Internet IP"
    Target = "1.1.1.1"
    Result = $internetResult
}

try {

    Resolve-DnsName microsoft.com `
        -ErrorAction Stop |
        Out-Null

    $dnsResult = $true

}
catch {

    $dnsResult = $false
}

$results += [PSCustomObject]@{
    Test   = "DNS"
    Target = "microsoft.com"
    Result = $dnsResult
}

$httpsResult = Test-NetConnection `
    microsoft.com `
    -Port 443 `
    -InformationLevel Quiet `
    -WarningAction SilentlyContinue

$results += [PSCustomObject]@{
    Test   = "HTTPS"
    Target = "microsoft.com:443"
    Result = $httpsResult
}

$results | Format-Table -AutoSize

# ------------------------------------------------------------
# NRPT / DNS POLICY
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== DNS / NRPT ==="

$nrptRules = Get-DnsClientNrptRule -ErrorAction SilentlyContinue

if ($nrptRules) {

    foreach ($rule in $nrptRules) {

        [PSCustomObject]@{
            Rule       = $rule.Name
            Namespace  = $rule.Namespace -join ", "
            NameServers = $rule.NameServers -join ", "
        } | Format-List
    }

}
else {
    Write-Host "No NRPT rules detected."
}

# ------------------------------------------------------------
# TAILSCALE CHECK
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== TAILSCALE ==="

$tailscaleCommand = Get-Command tailscale `
    -ErrorAction SilentlyContinue

$tailscaleDetected = $false
$tailscaleOnline   = $false

if ($tailscaleCommand) {

    $tailscaleDetected = $true

    try {

        $tailscaleStatus = tailscale status 2>$null

        if ($LASTEXITCODE -eq 0 -and $tailscaleStatus) {

            $tailscaleOnline = $true

            Write-Host "Tailscale installed: Yes"
            Write-Host "Tailscale status:    Online"

        }
        else {

            Write-Host "Tailscale installed: Yes"
            Write-Host "Tailscale status:    Not connected"

        }

    }
    catch {

        Write-Host "Tailscale installed: Yes"
        Write-Host "Tailscale status:    Unable to query"

    }

}
else {

    Write-Host "Tailscale installed: No"

}

# ------------------------------------------------------------
# RECENT DNS ERRORS
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== RECENT DNS EVENTS ==="

$dnsEvents = Get-WinEvent `
    -FilterHashtable @{
        LogName      = "System"
        ProviderName = "Microsoft-Windows-DNS-Client"
        Level        = 1,2
        StartTime    = (Get-Date).AddHours(-24)
    } `
    -ErrorAction SilentlyContinue

if ($dnsEvents) {

    $dnsSummary = $dnsEvents |
        Group-Object Id |
        Sort-Object Count -Descending |
        Select-Object -First 5 @{
            Name = "Count"
            Expression = { $_.Count }
        }, @{
            Name = "EventID"
            Expression = { $_.Group[0].Id }
        }, @{
            Name = "Newest"
            Expression = {
                ($_.Group |
                    Sort-Object TimeCreated -Descending |
                    Select-Object -First 1).TimeCreated
            }
        }

    $dnsSummary | Format-Table -AutoSize

}
else {

    Write-Host "No Critical/Error DNS events in last 24 hours."

}

# ------------------------------------------------------------
# ASSESSMENT
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== ASSESSMENT ==="

$failedTests = $results |
    Where-Object { $_.Test -in "Gateway", "DNS", "HTTPS" -and $_.Result -eq $false }

if ($failedTests.Count -eq 0) {

    Write-Host "[PASS] Basic network connectivity is healthy."

}
else {

    Write-Host "[WARN] One or more network tests failed."

}

if ($gateway -and -not ($results | Where-Object Test -eq "Gateway").Result) {

    Write-Host "[WARN] Gateway unreachable."
    Write-Host "       Investigate adapter, IP configuration, Wi-Fi/Ethernet, or local network."

}
elseif (
    ($results | Where-Object Test -eq "Gateway").Result -and
    -not ($results | Where-Object Test -eq "Internet IP").Result
) {

    Write-Host "[INFO] Internet ICMP did not respond. Ping may be blocked; use DNS and HTTPS as stronger evidence."

}
elseif (
    ($results | Where-Object Test -eq "Internet IP").Result -and
    -not ($results | Where-Object Test -eq "DNS").Result
) {

    Write-Host "[WARN] Internet reachability works but DNS resolution failed."
    Write-Host "       Likely DNS configuration or DNS policy issue."

}

if (
    $dnsEvents -and
    $dnsResult -and
    $httpsResult
) {

    Write-Host "[INFO] Historical DNS errors detected, but current DNS and HTTPS tests pass."

}

if ($tailscaleDetected -and $tailscaleOnline) {

    Write-Host "[INFO] Tailscale is installed and responding."

}
