$computer = Get-CimInstance Win32_ComputerSystem
$os       = Get-CimInstance Win32_OperatingSystem
$bios     = Get-CimInstance Win32_BIOS
$disk     = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$ramGB      = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
$freeGB     = [math]::Round($disk.FreeSpace / 1GB, 2)
$uptime     = (Get-Date) - $os.LastBootUpTime
$uptimeDays = [math]::Round($uptime.TotalDays, 1)

$warnings = @()

if ($freeGB -lt 20) {
    $warnings += "Low disk space: $freeGB GB free"
}

if ($uptimeDays -gt 14) {
    $warnings += "Uptime is high: $uptimeDays days"
}

$health = [PSCustomObject]@{
    Computer    = $env:COMPUTERNAME
    User        = $computer.UserName
    Manufacturer = $computer.Manufacturer
    Model       = $computer.Model
    Serial      = $bios.SerialNumber
    Windows     = $os.Caption
    RAM_GB      = $ramGB
    C_Free_GB   = $freeGB
    UptimeDays  = $uptimeDays
    MemoryFree_GB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    C_Free_Percent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
}

Write-Host ""
Write-Host "=== PC HEALTH ==="
$health | Format-List

Write-Host "=== TOP MEMORY PROCESSES ==="

Get-Process |
    Sort-Object WorkingSet -Descending |
    Select-Object -First 5 Name,
        @{Name="RAM_MB";Expression={[math]::Round($_.WorkingSet / 1MB,1)}} |
    Format-Table

Write-Host "=== WARNINGS ==="

if ($warnings.Count -eq 0) {
    Write-Host "No obvious issues detected."
}
else {
    foreach ($warning in $warnings) {
        Write-Host "[WARN] $warning"
    }
}
