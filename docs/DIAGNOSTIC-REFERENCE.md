# Diagnostic Reference

## Dashboard statistics

### Memory and disk gauges

Memory utilization comes from `Win32_OperatingSystem` and `Win32_ComputerSystem`. Disk utilization comes from `Win32_LogicalDisk` for C:.

High utilization is evidence of pressure, not automatically a fault. Memory may be intentionally used for caching, and a large disk can have a high used percentage while still retaining substantial free space.

### Network latency

- **Gateway:** bounded ICMP round-trip to the default-route gateway.
- **DNS:** time required to resolve `microsoft.com`.
- **HTTPS:** bounded TCP connection time to `microsoft.com:443`.

VPNs, wireless congestion, DNS policy, proxy inspection, or the remote service can influence these measurements. One slow sample should be repeated before drawing a conclusion.

### Event statistics

- **Total:** Critical and Error records from System and Application.
- **Patterns:** unique log/provider/Event ID combinations.
- **Critical:** Windows event level 1 records.
- **Recurring:** patterns appearing at least ten times in the snapshot window.

Event volume is not the same as impact. A noisy application can generate many harmless records.

## 2 — PC Health

Queries computer identity, Windows version, RAM, C: free space, uptime, and top memory-consuming processes.

Useful for resource pressure, low disk space, unexpectedly long uptime, and basic asset identification. Process memory is a moment-in-time observation; high use can be legitimate.

## 3 — Network Health

Finds the interface owning the IPv4 default route, then evaluates gateway, Internet IP, DNS, HTTPS, adapters, NRPT rules, Tailscale, and recent DNS events.

Interpret the failure boundary:

- Gateway fails: investigate local adapter, addressing, Wi-Fi/Ethernet, or local network.
- Gateway works but HTTPS fails: investigate upstream routing, VPN, firewall, proxy, or Internet access.
- Internet connectivity works but DNS fails: investigate DNS servers, NRPT, VPN policy, or resolver health.
- Internet IP ping fails while DNS and HTTPS pass: ICMP is probably blocked; this is informational.

## 4 — Event Health

Reads Critical and Error events from System and Application, groups repeated patterns, displays readable samples, and generates the next query.

False positives include historical failures, applications that retry noisily, expected disconnect events, and errors followed by successful recovery.

## 5 — Service Health

Compares current service state with operational expectations.

`Spooler`, `Winmgmt`, `Dnscache`, and `LanmanWorkstation` are expected to run for the supported workflows. `BITS` and `wuauserv` are on-demand and may legitimately stop while idle. Startup type helps explain why a service is stopped.

## 6 — Reboot State

Checks Component Based Servicing, Windows Update, and `PendingFileRenameOperations` registry indicators.

A pending reboot is INFO because it is a state, not automatically a fault. `PendingFileRenameOperations` can persist because of unrelated installers or security software.

## 7 — Software Health

Reads machine and user uninstall registry locations. It deliberately avoids `Win32_Product`, which can trigger MSI consistency checks and repairs.

Registry inventory can omit portable applications, Store applications, or software that does not register an uninstall entry.

## 8 — Driver / Device Health

Uses `Win32_PnPEntity.ConfigManagerErrorCode` to find present devices with actual Device Manager problem codes.

A generic status such as `Degraded` is not sufficient evidence. A nonzero problem code is actionable evidence, but recently disconnected or transient hardware can still require contextual interpretation.

## 9 — Windows Update Health

Shows update-service context, recent installed hotfixes, grouped Windows Update Client errors, and pending reboot indicators.

Stopped update services are not automatically unhealthy because Windows starts them on demand. A newer successful installation can show recovery after an older failure. `Get-HotFix` does not represent every Store, driver, or feature update.

## 10 — Security / BitLocker Health

Deep inspection queries Microsoft Defender, Windows Security Center antivirus registration, firewall profiles, BitLocker, Secure Boot, and TPM.

Common interpretation cautions:

- Defender may enter passive mode when third-party antivirus is active.
- Multiple registered antivirus entries can include stale registrations.
- A disabled firewall profile can be controlled by another security product or policy.
- BitLocker cmdlets may require elevation or may be unavailable on some editions.
- Secure Boot requires UEFI, and query failures are not proof it is disabled.

All checks are read-only.

