# Project overview

This repository defines a reproducible macOS workstation environment with Nix, nix-darwin, and Home Manager.

## Purpose

The setup is for macOS admin/operator workstations. It manages the base system, shell/editor tooling, terminal environment, privacy/security defaults, and YubiKey-backed authentication.

## Main technology

- Nix flakes
- nix-darwin for system configuration
- Home Manager for user configuration
- Shell helper scripts for imperative macOS/YubiKey steps

## Current validated host

- Hostname: `gdca-maintaince`
- User: `mliebreich`
- Platform: `aarch64-darwin`

## Current authentication state

YubiKey support is active and validated on `gdca-maintaince`.

- Primary YubiKey serial: `31021632`
- Backup YubiKey serial: `31021618`
- sudo requires a registered YubiKey
- sudo YubiKey factor is touch-only, not FIDO2-PIN verified
- macOS login/unlock is smart-card-only via PIV
- password-only macOS login/unlock fallback is removed
- FileVault remains password/recovery-key based
- FileVault YubiKey unlock is not enabled

FileVault smart-card unlock was investigated and is currently blocked: `sc_auth filevault` reports a SecureToken mismatch even though `sysadminctl`, `fdesetup list`, and APFS volume-owner checks show the user is FileVault/SecureToken authorized.

## Key modules

- `flake.nix` — machine-specific username/hostname and host-specific policy
- `hosts/default.nix` — shared host imports and base platform
- `home/default.nix` — Home Manager imports
- `modules/darwin/yubikey.nix` — YubiKey packages, sudo MFA, smart-card-only policy
- `modules/darwin/security.nix` — firewall and security/privacy defaults
- `modules/darwin/packages.nix` — common CLI packages and helper scripts
- `scripts/setup.sh` — bootstrap/apply helper

## Important helper scripts

- `yubikey-workstation-setup` — guided primary/backup YubiKey setup
- `yubikey-workstation-rotate` — guided existing-key rotation
- `yubikey-status` — YubiKey enrollment/readiness status
- `yubikey-policy-check` — local operational policy report
- `yubikey-smartcard-policy-status` — smart-card-only policy status
- `yubikey-filevault-status` — read-only FileVault smart-card discovery
- `macos-privacy-check` — privacy/security report and optional apply helper

## Safety boundaries

Do not change these without explicit validation:

- FileVault YubiKey unlock
- YubiKey PIV slot replacement with `--force`
- smart-card-only policy on unvalidated hosts
- removing or changing recovery/admin fallback paths

## Documentation

- `SETUP.md` — user setup instructions
- `docs/yubikey.md` — YubiKey details
- `docs/yubikey-operations.md` — YubiKey day-2 procedures
- `docs/yubikey-filevault.md` — FileVault discovery and blocker
- `docs/raycast.md` — Raycast setup notes
