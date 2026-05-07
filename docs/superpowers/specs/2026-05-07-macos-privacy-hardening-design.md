# macOS Privacy Hardening Design

## Goal

Automate as much privacy/security hardening as possible while keeping defaults suitable for a datacenter infrastructure operator / Linux system administrator workstation.

## Policy

Use nix-darwin for stable declarative macOS defaults and first-class nix-darwin options. Use `scripts/macos-privacy-check.sh` for settings that require imperative commands, root privileges, `systemsetup`, `networksetup`, `launchctl`, or per-user runtime writes.

The default `--apply` path should remain low-risk, reversible, and unlikely to break normal sysadmin work. Settings that are identity-bound, TCC-protected, MDM-only, undocumented/protected, or likely to break workflows remain check-only/manual.

## Automate by default

- Firewall: enable firewall, enable stealth mode, disable automatic allowance for built-in signed software, disable automatic allowance for downloaded signed software.
- Wi-Fi: disable “Ask to join networks” and “Ask to join hotspots”.
- Bluetooth: disable Bluetooth.
- AirDrop/Handoff: disable AirDrop and Handoff.
- Sharing: disable known local sharing services using `launchctl`, `systemsetup`, and service-specific tools where available.
- Siri / Apple Intelligence: disable Siri user prompts/menu state and known Apple Intelligence defaults where scriptable.
- Spotlight: disable Apple search improvement sharing. Do not fully disable Spotlight indexing by default because it can affect normal macOS app/file workflows; keep full disable as a future explicit flag when Raycast replacement is ready.
- Notifications: disable lock-screen/sleep/display-sharing notification behaviors where scriptable. Per-app notification disabling is check/manual unless a stable, non-protected method is available.
- Analytics / ads: disable Apple personalized advertising, diagnostics auto-submit, third-party diagnostics, and related improvement/reporting defaults.
- Date/time: keep automatic network time enabled, set NTP server to `pool.ntp.org`, and avoid location-based automatic timezone behavior where scriptable. This avoids clock drift issues with SSH, TLS, Kerberos, Git signing, logs, and incident timelines.

## Keep manual or check-only

- Apple ID and iCloud sign-in, iCloud Drive, iCloud Keychain, iCloud Photos.
- Location Services global/per-app permissions unless an explicit future flag is added.
- TCC permissions: Camera, Microphone, Accessibility, Full Disk Access, Screen Recording, Contacts, Calendars, etc. These require user approval or MDM profiles for reliable management.
- Siri per-app permissions where stored in protected/private databases.
- Per-app notification toggles where stored in protected/private databases.
- Outbound application firewall installation/configuration. Report whether LuLu or Little Snitch is present; leave installation for a later Homebrew/package-management design.

## Reporting

The script should distinguish:

- `[OK]`: confirmed hardened state.
- `[CHECK]`: not hardened, unknown, or needs user review.
- `[MANUAL]`: not suitable for local script automation.
- `[SKIP]`: intentionally left unchanged by current flags.

## Testing

Add shell tests using PATH stubs for commands like `defaults`, `systemsetup`, `networksetup`, `blueutil`, and `socketfilterfw` where possible. Tests should prove both reporting and `--apply` command intent without requiring real system changes.

## Scope notes

This design is one implementation unit: extend existing nix-darwin defaults and the existing macOS privacy check/apply helper. It does not add Homebrew, MDM profile generation, or a full replacement launcher configuration.
