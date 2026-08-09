param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][int]$EventId,
    [ValidateRange(1, 720)][int]$Hours = 24,
    [ValidateRange(1, 100)][int]$MaxEvents = 10
)

$events = @(Get-WinEvent -FilterHashtable @{
    LogName = "System", "Application"
    ProviderName = $Provider
    Id = $EventId
    StartTime = (Get-Date).AddHours(-$Hours)
} -ErrorAction SilentlyContinue | Sort-Object TimeCreated -Descending | Select-Object -First $MaxEvents)

Write-Host ""
Write-Host "=== EVENT DETAILS ==="
Write-Host "Provider: $Provider | Event ID: $EventId | Window: $Hours hours | Found: $($events.Count)"

if (-not $events.Count) {
    Write-Host "[INFO] No matching events were found in System or Application."
    return
}

$events | Select-Object TimeCreated, LogName, LevelDisplayName, Id, Message | Format-List
Write-Host "[INFO] Repetition and timing support correlation; the message still requires technical judgment."
