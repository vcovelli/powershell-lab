param(
    [ValidateRange(1, 168)][int]$Hours = 24,
    [ValidateRange(1, 50)][int]$Top = 10
)

$since = (Get-Date).AddHours(-$Hours)
$events = @(Get-WinEvent -FilterHashtable @{
    LogName = "System", "Application"
    Level = 1, 2
    StartTime = $since
} -ErrorAction SilentlyContinue)

Write-Host ""
Write-Host "=== EVENT HEALTH ($Hours HOURS) ==="

if (-not $events.Count) {
    Write-Host "[PASS] No Critical or Error events were found."
    return
}

$groups = $events | Group-Object LogName, ProviderName, Id | ForEach-Object {
    $newest = $_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
    $message = (($newest.Message -replace "\s+", " ").Trim())
    if ($message.Length -gt 100) { $message = $message.Substring(0, 97) + "..." }
    [PSCustomObject]@{
        Count = $_.Count
        Level = $newest.LevelDisplayName
        Log = $newest.LogName
        Provider = $newest.ProviderName
        EventId = $newest.Id
        Newest = $newest.TimeCreated
        AgeHours = [math]::Round(((Get-Date) - $newest.TimeCreated).TotalHours, 1)
        Sample = $message
    }
} | Sort-Object Count, Newest -Descending

Write-Host "Events: $($events.Count) | Unique patterns: $($groups.Count) | Since: $($since.ToString('yyyy-MM-dd HH:mm'))"
Write-Host ""
$groups | Select-Object -First $Top Count, Level, Log, Provider, EventId, Newest |
    Format-Table -AutoSize | Out-Host

Write-Host "=== MOST RELEVANT SAMPLES ==="
foreach ($group in ($groups | Select-Object -First 5)) {
    Write-Host ""
    Write-Host "[$($group.Level)] $($group.Provider) / $($group.EventId)  ($($group.Count)x, newest $($group.AgeHours)h ago)"
    Write-Host $group.Sample
}

$critical = @($events | Where-Object Level -eq 1)
$recurring = @($groups | Where-Object Count -ge 5)
$veryRecent = @($groups | Where-Object AgeHours -le 2)

Write-Host ""
Write-Host "=== EVENT ASSESSMENT ==="
if ($critical.Count) {
    Write-Host "[WARN] $($critical.Count) critical event(s) occurred in the selected window."
}
elseif ($recurring.Count -and $veryRecent.Count) {
    Write-Host "[WARN] Errors are both recurring and active within the last two hours."
}
else {
    Write-Host "[INFO] Errors exist, but event records alone do not prove a current fault."
}
Write-Host "       Correlate the newest timestamp and message with the user's symptom."

$lead = $groups | Select-Object -First 1
$escapedProvider = $lead.Provider -replace "'", "''"
Write-Host ""
Write-Host "NEXT QUERY"
Write-Host ".\scripts\Get-EventDetails.ps1 -Provider '$escapedProvider' -EventId $($lead.EventId) -Hours $Hours"
