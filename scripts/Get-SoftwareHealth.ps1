param(
    [string]$Name,
    [switch]$All
)

Write-Host ""
Write-Host "=== SOFTWARE HEALTH ==="

# Registry locations commonly used for installed application inventory.
$paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$software = Get-ItemProperty `
    -Path $paths `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName
    } |
    Select-Object `
        DisplayName,
        DisplayVersion,
        Publisher,
        InstallDate,
        InstallLocation,
        UninstallString |
    Sort-Object DisplayName -Unique

Write-Host ""
Write-Host "Installed applications found: $($software.Count)"
Write-Host ""

# ------------------------------------------------------------
# SEARCH MODE
# ------------------------------------------------------------

if ($Name) {

    Write-Host "=== SEARCH RESULTS ==="
    Write-Host "Search: $Name"
    Write-Host ""

    $matches = $software |
        Where-Object {
            $_.DisplayName -like "*$Name*"
        }

    if ($matches) {

        $matches |
            Select-Object `
                DisplayName,
                DisplayVersion,
                Publisher,
                InstallDate |
            Format-Table -AutoSize

    }
    else {

        Write-Host "[INFO] No installed application matched '$Name'."

    }

    return
}

# ------------------------------------------------------------
# DEFAULT SUMMARY
# ------------------------------------------------------------

Write-Host "=== SOFTWARE SUMMARY ==="

if ($All) {
    $software |
    Select-Object `
        DisplayName,
        DisplayVersion,
        Publisher,
        InstallDate |
        Format-Table -AutoSize
}
else {
    Write-Host "Inventory is available. Use -Name <text> to search or -All to display every entry."
}

# ------------------------------------------------------------
# COMMON APPLICATION CHECKS
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== COMMON APPLICATIONS ==="

$commonApps = @(
    "Google Chrome",
    "Microsoft Edge",
    "Microsoft Visual Studio Code",
    "Tailscale",
    "ProtonVPN",
    "Microsoft Teams",
    "Microsoft 365",
    "OneDrive"
)

$commonResults = foreach ($app in $commonApps) {

    $match = $software |
        Where-Object {
            $_.DisplayName -like "*$app*"
        } |
        Select-Object -First 1

    if ($match) {

        [PSCustomObject]@{
            Application = $app
            Installed   = $true
            Version     = $match.DisplayVersion
            Publisher   = $match.Publisher
        }

    }
    else {

        [PSCustomObject]@{
            Application = $app
            Installed   = $false
            Version     = ""
            Publisher   = ""
        }

    }
}

$commonResults |
    Format-Table -AutoSize

# ------------------------------------------------------------
# ASSESSMENT
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== SOFTWARE ASSESSMENT ==="

if ($software.Count -gt 0) {

    Write-Host "[PASS] Software inventory completed successfully."

}
else {

    Write-Host "[WARN] No installed applications were discovered through the expected registry locations."

}
