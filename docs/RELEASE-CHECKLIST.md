# Release and Workplace Checklist

## Before packaging

- Run `./tests/Test-All.ps1` in Windows PowerShell 5.1.
- Run `./tests/Test-All.ps1` in PowerShell 7 when it is available.
- Confirm the console works without administrator rights.
- Confirm no reports contain usernames, serial numbers, internal hostnames,
  IP addresses, event messages, or other data that should not be shared.

## Before using it at work

- Obtain approval from the employer's IT or security owner.
- Review the scripts against execution-policy, application-control, endpoint
  detection, data-handling, and support-tool policies.
- Test on a non-production, company-managed Windows endpoint as a standard user.
- Keep diagnostic output in an approved location and retention period.
- Do not collect or store passwords, credentials, tokens, or BitLocker recovery
  keys.

## Release contents

The release archive should include `Start-SupportConsole.ps1`, `VERSION`,
`README.md`, `scripts`, `tests`, `docs`, and the empty `reports` directory. It
should not include `.git`, existing reports, logs, or previous release archives.
