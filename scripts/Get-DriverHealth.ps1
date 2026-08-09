param([switch]$IncludeInventory)

Write-Host ""
Write-Host "=== DRIVER / DEVICE HEALTH ==="

# ConfigManagerErrorCode is the problem code shown by Device Manager. A generic
# PnP status such as "Degraded" is not, by itself, evidence of a device fault.
$problemDevices = Get-CimInstance Win32_PnPEntity `
    -Filter "ConfigManagerErrorCode <> 0" `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.Present -ne $false } |
    Sort-Object PNPClass, Name -Unique

Write-Host ""
Write-Host "=== PROBLEM DEVICES ==="

if ($problemDevices) {

    $problemDevices |
        Select-Object @{Name="ProblemCode";Expression={$_.ConfigManagerErrorCode}},
                      @{Name="Class";Expression={$_.PNPClass}},
                      @{Name="Device";Expression={$_.Name}},
                      @{Name="InstanceId";Expression={$_.PNPDeviceID}} |
        Format-Table -AutoSize

}
else {

    Write-Host "[PASS] No present Plug and Play devices have Device Manager problem codes."

}

if ($IncludeInventory) {
Write-Host ""
Write-Host "=== RECENT SIGNED DRIVER INVENTORY ==="

$drivers = Get-CimInstance Win32_PnPSignedDriver `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DeviceName
    }

Write-Host "Drivers found: $($drivers.Count)"
Write-Host ""

$recentDrivers = $drivers |
    Where-Object {
        $_.DriverDate
    } |
    Sort-Object DriverDate -Descending |
    Select-Object -First 15 `
        DeviceName,
        Manufacturer,
        DriverVersion,
        DriverDate

$recentDrivers |
    Format-Table -AutoSize
}
else {
    Write-Host ""
    Write-Host "[INFO] Full signed-driver inventory skipped for speed. Use -IncludeInventory when needed."
}

Write-Host ""
Write-Host "=== DISPLAY / NETWORK / AUDIO ==="

$importantClasses = @(
    "Display",
    "Net",
    "MEDIA"
)

$importantDevices = foreach ($class in $importantClasses) {

    Get-PnpDevice -Class $class -ErrorAction SilentlyContinue |
        Select-Object `
            @{Name="Class";Expression={$class}},
            Status,
            FriendlyName
}

$importantDevices |
    Format-Table -AutoSize

Write-Host ""
Write-Host "=== DRIVER ASSESSMENT ==="

if ($problemDevices) {

    Write-Host "[WARN] One or more present devices have a Device Manager problem code."
    Write-Host "       Investigate the listed problem code, Device Manager status,"
    Write-Host "       driver version, recent updates, and related Event Logs."

}
else {

    Write-Host "[PASS] No actionable Device Manager problem codes detected."

}
