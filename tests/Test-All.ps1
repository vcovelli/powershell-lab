$tests = Get-ChildItem $PSScriptRoot -Filter "Test-*.ps1" -File |
    Where-Object Name -ne "Test-All.ps1" |
    Sort-Object Name

$failed = $false
foreach ($test in $tests) {
    Write-Host "Running $($test.Name)..." -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    & $test.FullName
    if ($LASTEXITCODE -ne 0) {
        $failed = $true
    }
}

if ($failed) {
    Write-Error "One or more tests failed."
    exit 1
}

Write-Host "[PASS] All $($tests.Count) test files passed."
