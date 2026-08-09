Write-Host ""
Write-Host "=== REBOOT HEALTH ==="

$rebootReasons = @()

$checks = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
)

foreach ($path in $checks) {
    if (Test-Path $path) {
        $rebootReasons += $path
    }
}

$pendingFileRename = Get-ItemProperty `
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
    -Name PendingFileRenameOperations `
    -ErrorAction SilentlyContinue

if ($pendingFileRename.PendingFileRenameOperations) {
    $rebootReasons += "PendingFileRenameOperations"
}

if ($rebootReasons.Count -gt 0) {
    Write-Host "[INFO] Pending reboot detected."

    foreach ($reason in $rebootReasons) {
        Write-Host " - $reason"
    }
}
else {
    Write-Host "[PASS] No common pending reboot indicators detected."
}