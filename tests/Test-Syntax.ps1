$projectRoot = Split-Path $PSScriptRoot -Parent
$files = @(Get-ChildItem $projectRoot -Filter "*.ps1" -File -Recurse)
$failures = @()

foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$errors
    )
    foreach ($error in $errors) {
        $failures += "$($file.Name): $($error.Message)"
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "[PASS] Parsed $($files.Count) PowerShell scripts without syntax errors."
