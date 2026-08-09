# Operator Guide

## Starting a session

Run `support` if the shortcut exists. Otherwise:

```powershell
Set-Location C:\Path\To\powershell-lab
.\Start-SupportConsole.ps1
```

You can also open the extracted project folder in File Explorer, right-click
inside it, choose **Open in Terminal**, and run the second command. No fixed
installation path is required.

The console collects one live snapshot and then displays the dashboard. Navigation does not continuously repeat the slow checks. Option `1` deliberately refreshes them.

## Reading the screen

Read the screen from top to bottom:

1. **Health bar:** count of PASS, INFO, and WARN areas.
2. **Triage score:** quick prioritization only; lower means more areas deserve inspection.
3. **System pressure:** memory and C: drive utilization.
4. **Event statistics:** error volume, unique patterns, critical events, and recurring patterns.
5. **Area table:** one concise result for each menu option.
6. **Priority queue:** WARN items first, followed by INFO items.
7. **Menu or drill-down:** the content that changes while the dashboard stays visible.

## Example investigation

Suppose the dashboard shows:

```text
4 Events   WARN   121 Critical/Error events in last 24h
6 Reboot   INFO   Pending reboot detected
9 Updates  WARN   3 failure events in 7d
```

Do not assume all three findings share one cause.

1. Choose `4` and identify the largest recent event patterns.
2. Compare their newest timestamps with when the user experienced the problem.
3. Run the exact Event Details command printed by Event Health.
4. Choose `9` to see whether update failures were followed by a successful installation.
5. Choose `6` to identify which Windows component requested a reboot.
6. Decide whether the evidence explains the user's symptom before taking action.

## Event investigation

Event Health groups records by log, provider, and Event ID. This turns hundreds of records into a small number of patterns.

```powershell
.\scripts\Get-EventHealth.ps1 -Hours 24 -Top 10
```

Then inspect one pattern:

```powershell
.\scripts\Get-EventDetails.ps1 `
    -Provider 'Microsoft-Windows-WindowsUpdateClient' `
    -EventId 20 `
    -Hours 24 `
    -MaxEvents 10
```

Ask:

- Did the event happen when the symptom occurred?
- Is it repeating now, or is it historical?
- Does the message name the affected application, device, or component?
- Is there current functional evidence that confirms the event?

## Software and driver searches

Search software by name instead of dumping the full inventory:

```powershell
.\scripts\Get-SoftwareHealth.ps1 -Name 'Proton'
```

Driver Health defaults to actual Device Manager problem codes. The slower signed-driver inventory is opt-in:

```powershell
.\scripts\Get-DriverHealth.ps1 -IncludeInventory
```

## Finishing a session

- Record the symptom, relevant timestamps, and evidence that supports the conclusion.
- Distinguish current failures from historical log entries.
- Do not report a WARN status alone as root cause.
- Press `Q` to close the console.
