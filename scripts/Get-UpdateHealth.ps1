Write-Host ""
Write-Host "=== WINDOWS UPDATE HEALTH ==="

# ------------------------------------------------------------
# UPDATE SERVICES
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== UPDATE SERVICES ==="

$serviceNames = @(
    "wuauserv",
    "BITS",
    "UsoSvc"
)

$services = foreach ($name in $serviceNames) {

    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

    if ($svc) {

        [PSCustomObject]@{
            Service = $svc.Name
            Status  = $svc.Status
        }

    }
}

$services | Format-Table -AutoSize


# ------------------------------------------------------------
# RECENT INSTALLED UPDATES
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== RECENT INSTALLED UPDATES ==="

$updates = Get-HotFix -ErrorAction SilentlyContinue |
    Where-Object InstalledOn |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 10 `
        HotFixID,
        Description,
        InstalledOn

if ($updates) {

    $updates | Format-Table -AutoSize

}
else {

    Write-Host "[INFO] No update history returned by Get-HotFix."

}


# ------------------------------------------------------------
# WINDOWS UPDATE ERRORS
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== RECENT UPDATE ERRORS ==="

$updateErrors = Get-WinEvent `
    -FilterHashtable @{
        LogName      = "System"
        ProviderName = "Microsoft-Windows-WindowsUpdateClient"
        Level        = 2
        StartTime    = (Get-Date).AddDays(-7)
    } `
    -ErrorAction SilentlyContinue

$newestError = $updateErrors |
    Sort-Object TimeCreated -Descending |
    Select-Object -First 1

$latestInstalledUpdate = $updates |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 1

if ($updateErrors) {

    $updateErrors |
        Group-Object Id |
        ForEach-Object {
            $newest = $_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
            [PSCustomObject]@{
                Count = $_.Count
                EventId = $newest.Id
                Newest = $newest.TimeCreated
                Message = (($newest.Message -replace "\s+", " ").Trim())
            }
        } |
        Sort-Object Count -Descending |
        Format-Table -Wrap | Out-Host

}
else {

    Write-Host "[PASS] No Windows Update errors detected in the last 7 days."

}


# ------------------------------------------------------------
# PENDING REBOOT
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== REBOOT CHECK ==="

$rebootPending = $false

if (
    Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
) {
    $rebootPending = $true
}

if (
    Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
) {
    $rebootPending = $true
}

$pendingRename = Get-ItemProperty `
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
    -Name PendingFileRenameOperations `
    -ErrorAction SilentlyContinue

if ($pendingRename.PendingFileRenameOperations) {
    $rebootPending = $true
}

if ($rebootPending) {

    Write-Host "[INFO] Windows has pending reboot indicators."

}
else {

    Write-Host "[PASS] No common pending reboot indicators detected."

}


# ------------------------------------------------------------
# ASSESSMENT
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== UPDATE ASSESSMENT ==="

if ($newestError -and $latestInstalledUpdate -and
    $latestInstalledUpdate.InstalledOn -gt $newestError.TimeCreated) {

    Write-Host "[INFO] Update failures were logged, but a newer update was installed successfully."
    Write-Host "       Confirm the failed item in Settings > Windows Update > Update history."

}
elseif ($updateErrors) {

    Write-Host "[WARN] Windows Update errors were detected recently."
    Write-Host "       Review the error messages above before taking action."

}
else {

    Write-Host "[PASS] No obvious recent Windows Update failures detected."

}

if ($rebootPending) {

    Write-Host "[INFO] A reboot may be required to complete pending operations."

}

if ($services) {
    Write-Host "[INFO] Update services may legitimately stop when idle; service state alone is not a failure."
}
