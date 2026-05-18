# YubiKey setup

This repository is being extended for YubiKey-backed workstation authentication for system administrators and infrastructure operators.

## Current status

Phase 1 and the safe part of Phase 2 are implemented:

- YubiKey tools are installed by nix-darwin.
- `yubikey-check` verifies the tools and detects inserted YubiKeys.
- `yubikey-enroll` records local enrollment inventory for the current macOS user.
- `yubikey-harden` interactively changes default PIV credentials and sets a FIDO2 PIN.
- `yubikey-status` reports inventory, inserted-key hardening, and readiness for future enforcement.
- `yubikey-sudo-register` creates a per-user pam_u2f mapping for optional sudo MFA.
- `yubikey-sudo-test` validates sudo MFA with a guided `sudo -k` / `sudo -v` flow.
- `yubikey-piv-login-setup` prepares a self-signed PIV certificate for optional macOS smart-card login pairing.
- `yubikey-piv-login-status` reports macOS smart-card identities, pairings, and FileVault smart-card status.
- `yubikey-policy-check` reports local operational-policy compliance without changing authentication settings.
- `yubikey-smartcard-policy-status` reports smart-card-only login policy state without changing authentication settings.
- `yubikey-filevault-status` performs read-only FileVault smart-card unlock discovery.
- `yubikey-filevault-enable` performs guarded FileVault smart-card unlock preflight and optional explicit enablement.
- `yubikey-workstation-setup` guides operators through primary/backup YubiKey setup interactively.
- `yubikey-workstation-rotate` guides existing-key PIN, sudo MFA, and optional PIV identity rotation.
- `scripts/setup.sh` runs `yubikey-enroll` by default.
- `scripts/setup.sh` reports `yubikey-status` after enrollment.
- Use `scripts/setup.sh --skip-yubikey` for test runs or machines that must not enroll/check a key.

The reusable YubiKey module defaults to **no authentication enforcement**. The `gdca-maintaince` host explicitly opts in to sudo MFA and smart-card-only login after validating both enrolled keys. This repo still does **not** implement FileVault YubiKey unlock.

## FileVault limitation

FileVault pre-boot disk unlock remains password/recovery-key based. The YubiKey setup is for post-boot authentication such as macOS login/screen unlock, sudo MFA, SSH, VPN, or future service authentication.

Do not depend on this repo to provide YubiKey-only FileVault disk unlock. Use `yubikey-filevault-status` for read-only discovery only; see [`yubikey-filevault.md`](yubikey-filevault.md).

## Tools installed

The nix-darwin module `modules/darwin/yubikey.nix` installs:

- `ykman` from `yubikey-manager`
- `yubico-piv-tool`
- `opensc-tool` from OpenSC
- `fido2-token` from libfido2
- `gpg`
- `pinentry-mac`
- `pam_u2f` / `pamu2fcfg`
- `yubikey-check`
- `yubikey-enroll`
- `yubikey-harden`
- `yubikey-status`
- `yubikey-sudo-register`
- `yubikey-sudo-test`
- `yubikey-piv-login-setup`
- `yubikey-piv-login-status`
- `yubikey-policy-check`
- `yubikey-smartcard-policy-status`
- `yubikey-filevault-status`
- `yubikey-filevault-enable`
- `yubikey-workstation-setup`
- `yubikey-workstation-rotate`

## Setup behavior

Default setup requires and records a visible YubiKey after the nix-darwin switch, then prints readiness status:

```sh
./scripts/setup.sh
```

Skip the YubiKey step explicitly:

```sh
./scripts/setup.sh --skip-yubikey
```

For a guided full primary/backup workstation flow, run:

```sh
yubikey-workstation-setup
```

This wizard pauses before each step and can guide enrollment, hardening, sudo registration, PIV pairing, read-only validation, and an optional FileVault smart-card unlock preflight/enable flow. FileVault enablement remains explicit and requires typed confirmations.

For existing-key maintenance/rotation, run:

```sh
yubikey-workstation-rotate
```

Safe default rotation covers PIV PIN/PUK/management-key prompts, sudo MFA re-registration, pairing/status checks, and final read-only checks. PIV slot key/certificate replacement is destructive and requires `--replace-piv-identity`.

Run enrollment directly:

```sh
yubikey-enroll
```

If multiple keys are inserted, choose one explicitly:

```sh
yubikey-enroll --serial 31021632
```

Track primary and backup key roles:

```sh
yubikey-enroll --role primary
yubikey-enroll --role backup
```

If an older enrollment record exists without a role, re-record it as primary:

```sh
yubikey-enroll --role primary --force
```

Enrollment writes a local inventory record to:

```text
~/.config/nix-macos/yubikeys.tsv
```

Harden a key interactively:

```sh
yubikey-harden
```

Check hardening state without changing the key:

```sh
yubikey-harden --check-only
```

The hardening helper can change:

- default PIV PIN
- default PIV PUK
- default PIV management key, replacing it with a random PIN-protected key
- missing FIDO2 PIN

Report workstation YubiKey status/readiness:

```sh
yubikey-status
```

Use strict mode in scripts/CI-style checks:

```sh
yubikey-status --strict
```

Register the inserted YubiKey for optional sudo MFA:

```sh
yubikey-sudo-register
```

Validate sudo MFA after enabling it:

```sh
yubikey-sudo-test
```

This writes the pam_u2f mapping to:

```text
~/.config/Yubico/u2f_keys
```

It does not enable sudo MFA by itself. Sudo MFA remains host-specific and opt-in in Nix:

```nix
gdca.yubikey.sudoMfa.enable = true;
# Optional lower-friction policy: require YubiKey touch but not FIDO2 PIN for sudo.
gdca.yubikey.sudoMfa.pinVerification = false;
```

Do not enable this on another host until a hardened backup key and a recovery/admin path are tested. See [`yubikey-sudo-mfa.md`](yubikey-sudo-mfa.md).

Prepare a self-signed PIV certificate for optional macOS smart-card login:

```sh
yubikey-piv-login-setup
```

Optionally pair it to the local macOS user:

```sh
yubikey-piv-login-setup --pair
```

Report smart-card login status:

```sh
yubikey-piv-login-status
```

See [`yubikey-piv-login.md`](yubikey-piv-login.md).

Run FileVault smart-card unlock preflight without changes:

```sh
yubikey-filevault-enable --dry-run
```

Run recovery/admin verification before enablement:

```sh
yubikey-filevault-enable --verify-recovery --hash HASH
```

After recovery verification records a checkpoint, execute mode remains blocked on hosts with smart-card-only login enforced. A real pre-boot lockout was observed during testing, so FileVault smart-card unlock is not production-ready in this repo.

This is intentionally not run automatically by Nix activation. See [`yubikey-filevault.md`](yubikey-filevault.md).

Report local operational-policy compliance:

```sh
yubikey-policy-check
```

If this workstation requires two PIV/smart-card pairings, run:

```sh
yubikey-policy-check --require-piv-pairings 2
```

See [`yubikey-operations.md`](yubikey-operations.md).

Report smart-card-only login policy state:

```sh
yubikey-smartcard-policy-status --require-pairings 2
```

Smart-card-only login removes password-only login/unlock fallback for affected accounts when enabled on a validated host. See [`yubikey-smartcard-only.md`](yubikey-smartcard-only.md) before applying.

Run the check directly:

```sh
yubikey-check
```

For a non-blocking diagnostic:

```sh
yubikey-check --warn-only
```

## Operational recommendations

- Each user should have at least two YubiKeys: primary and backup.
- Record the first key with `yubikey-enroll --role primary` and the second key with `yubikey-enroll --role backup`.
- Do not enable login or sudo enforcement on a host until the backup key and recovery process are tested.
- Before enabling sudo MFA, run `yubikey-sudo-register` for each physical key that should authorize sudo.
- Keep FileVault recovery keys escrowed outside the laptop.
- Record YubiKey serial numbers in the organization's asset or credential inventory.
