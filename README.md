# nix-macos-env project state

This README is intentionally a short project-state note for AI/coding-agent context.

User-facing setup instructions are in [`SETUP.md`](SETUP.md).
Technical project overview is in [`PROJECT.md`](PROJECT.md).

## Current validated machine

- Hostname: `gdca-maintaince`
- User: `mliebreich`
- Platform: Apple Silicon / `aarch64-darwin`

## Current validated YubiKey state

- Primary YubiKey serial: `31021632`
- Backup YubiKey serial: `31021618`
- Both keys are enrolled, hardened, and registered.
- sudo MFA is enabled.
- sudo YubiKey factor is touch-only: `gdca.yubikey.sudoMfa.pinVerification = false`.
- macOS smart-card-only login is enabled for this host.
- Password-only macOS login/unlock fallback is removed.
- FileVault remains password/recovery-key based.
- FileVault YubiKey unlock is not enabled and is currently blocked for the local `sc_auth filevault` path.

## Main entry points

- `./scripts/setup.sh` — bootstrap/apply helper; safe YubiKey enrollment/status only
- `yubikey-workstation-setup` — guided primary/backup YubiKey setup
- `yubikey-workstation-rotate` — guided existing-key rotation
- `yubikey-policy-check --require-piv-pairings 2` — YubiKey policy report
- `yubikey-smartcard-policy-status --require-pairings 2` — smart-card-only login status
- `yubikey-filevault-status` — read-only FileVault smart-card discovery
- `power-status` — read-only AC/battery sleep policy report

## Important safety constraints

Do not change these without explicit user validation:

- FileVault YubiKey unlock
- smart-card-only login policy on unvalidated hosts
- PIV slot `9a` replacement / `--force`
- recovery/admin fallback assumptions

## Important files

- `flake.nix` — machine values and host-specific policy
- `hosts/default.nix` — common host module imports
- `home/` — Home Manager user config
- `modules/darwin/` — nix-darwin modules
- `scripts/` — setup, validation, YubiKey, and privacy helpers
- `docs/yubikey*.md` — detailed YubiKey documentation

## Validation commands

Before claiming work is complete, prefer running relevant checks:

```sh
bash -n scripts/*.sh tests/*.sh
nix build --no-link .#darwinConfigurations.gdca-maintaince.system
```

YubiKey-specific checks:

```sh
yubikey-status
yubikey-policy-check --require-piv-pairings 2
yubikey-smartcard-policy-status --require-pairings 2
yubikey-filevault-status
```
