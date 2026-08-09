Write-Host ""
Write-Host "=== SECURITY HEALTH ==="

# ------------------------------------------------------------
# WINDOWS DEFENDER
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== MICROSOFT DEFENDER ==="

$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
$registeredAntivirus = Get-CimInstance -Namespace "root/SecurityCenter2" `
    -ClassName AntivirusProduct -ErrorAction SilentlyContinue

if ($defender) {

    [PSCustomObject]@{
        AntivirusEnabled       = $defender.AntivirusEnabled
        RealTimeProtection     = $defender.RealTimeProtectionEnabled
        BehaviorMonitor        = $defender.BehaviorMonitorEnabled
        AntivirusSignatureAge  = $defender.AntivirusSignatureAge
        LastQuickScan          = $defender.QuickScanEndTime
    } | Format-List

}
else {
    Write-Host "[INFO] Microsoft Defender status unavailable."
}

if ($registeredAntivirus) {
    Write-Host "Registered antivirus: $($registeredAntivirus.displayName -join ', ')"
}


# ------------------------------------------------------------
# WINDOWS FIREWALL
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== WINDOWS FIREWALL ==="

$firewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue

if ($firewallProfiles) {

    $firewallProfiles |
        Select-Object Name, Enabled |
        Format-Table -AutoSize

}
else {
    Write-Host "[INFO] Firewall profile information unavailable."
}


# ------------------------------------------------------------
# BITLOCKER
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== BITLOCKER ==="

$bitlockerAvailable = Get-Command Get-BitLockerVolume `
    -ErrorAction SilentlyContinue

$bitlocker = $null

if ($bitlockerAvailable) {

    $bitlocker = Get-BitLockerVolume `
        -MountPoint "C:" `
        -ErrorAction SilentlyContinue

    if ($bitlocker) {

        [PSCustomObject]@{
            Drive            = $bitlocker.MountPoint
            VolumeStatus     = $bitlocker.VolumeStatus
            ProtectionStatus = $bitlocker.ProtectionStatus
            Encryption       = $bitlocker.EncryptionPercentage
        } | Format-List

    }
    else {
        Write-Host "[INFO] BitLocker information for C: unavailable."
    }

}
else {
    Write-Host "[INFO] BitLocker PowerShell cmdlets unavailable."
}


# ------------------------------------------------------------
# SECURE BOOT
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== SECURE BOOT ==="

try {

    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop

    if ($secureBoot) {
        Write-Host "[PASS] Secure Boot is enabled."
    }
    else {
        Write-Host "[WARN] Secure Boot is disabled."
    }

}
catch {
    Write-Host "[INFO] Secure Boot state could not be queried."
}


# ------------------------------------------------------------
# TPM
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== TPM ==="

$tpm = Get-Tpm -ErrorAction SilentlyContinue

if ($tpm) {

    [PSCustomObject]@{
        Present = $tpm.TpmPresent
        Ready   = $tpm.TpmReady
        Enabled = $tpm.TpmEnabled
    } | Format-List

}
else {
    Write-Host "[INFO] TPM information unavailable."
}


# ------------------------------------------------------------
# ASSESSMENT
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== SECURITY ASSESSMENT ==="

if ($defender) {

    if ($defender.AntivirusEnabled -and
        $defender.RealTimeProtectionEnabled) {

        Write-Host "[PASS] Microsoft Defender protection is active."

    }
    elseif ($registeredAntivirus) {

        Write-Host "[INFO] Defender is not fully active; another antivirus product is registered."

    }
    else {

        Write-Host "[WARN] Microsoft Defender is not fully active."
        Write-Host "       No alternate antivirus product was found in Windows Security Center."

    }

}

if ($firewallProfiles) {

    $disabledProfiles = $firewallProfiles |
        Where-Object Enabled -eq $false

    if ($disabledProfiles) {

        Write-Host "[INFO] One or more Windows Firewall profiles are disabled."

    }
    else {

        Write-Host "[PASS] Windows Firewall is enabled on all profiles."

    }

}

if ($bitlocker) {

    if ($bitlocker.ProtectionStatus -eq "On") {

        Write-Host "[PASS] BitLocker protection is enabled on C:."

    }
    else {

        Write-Host "[INFO] BitLocker protection is not currently enabled on C:."

    }

}

if ($tpm) {

    if ($tpm.TpmPresent -and $tpm.TpmReady) {

        Write-Host "[PASS] TPM is present and ready."

    }
    else {

        Write-Host "[WARN] TPM is missing or not ready."

    }

}
