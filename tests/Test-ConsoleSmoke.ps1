$projectRoot = Split-Path $PSScriptRoot -Parent
$consoleScript = Join-Path $projectRoot "Start-SupportConsole.ps1"
$consoleErrors = @()

$output = @(& $consoleScript -Once -ErrorVariable +consoleErrors 6>&1 | Out-String)

if ($consoleErrors.Count) {
    $consoleErrors | ForEach-Object { Write-Error $_ }
    exit 1
}

$rendered = $output -join "`n"
foreach ($expectedText in "ENDPOINT SUPPORT CONSOLE", "SNAPSHOT ONLY", "AREA") {
    if ($rendered -notmatch [regex]::Escape($expectedText)) {
        Write-Error "Console output did not contain '$expectedText'."
        exit 1
    }
}

Write-Host "[PASS] Non-interactive console render completed without PowerShell errors."
