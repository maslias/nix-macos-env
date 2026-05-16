# YubiKey implementation plan

Goal: make YubiKey enrollment a normal part of workstation setup for infrastructure/admin users, while preserving an explicit escape hatch for machines or test runs that should not enroll a key.

Important constraint: FileVault pre-boot disk unlock remains password/recovery-key based. The YubiKey setup covers post-boot macOS/user authentication and future authentication use cases such as sudo, SSH, VPN, or service logins.

## Phase 1: safe tooling and setup integration

- Add a nix-darwin YubiKey module that installs required tools.
- Add a `yubikey-check` helper script that verifies tooling and detects inserted YubiKey 5C devices.
- Add `--skip-yubikey` to `scripts/setup.sh`.
- Run the YubiKey check by default during setup after the nix-darwin switch. **Done in initial Phase 1; superseded by safe enrollment in Phase 2.**
- Document the current support boundary and rollout model.

This phase must not change login, FileVault, or PAM enforcement.

## Phase 2: enrollment workflow

- Add `scripts/yubikey-enroll.sh`. **Done for local inventory enrollment.**
- Make setup run enrollment by default instead of only the check. **Done.**
- Require confirmation of at least one inserted YubiKey. **Done.**
- Detect serial/model and record/display serials for operator inventory. **Done locally in `~/.config/nix-macos/yubikeys.tsv`.**
- Check default PIN/PUK state and require changing defaults before enforcement. **Done via interactive `yubikey-harden`; setup enforcement is still deferred.**
- Recommend enrolling two keys per user: primary and backup. **Done in script/docs.**
- Track primary/backup roles in local enrollment inventory. **Done via `yubikey-enroll --role primary|backup`.**
- Add status/readiness reporting before auth enforcement. **Done via `yubikey-status`; setup now prints this report after enrollment.**

## Phase 3: optional sudo MFA

- Add opt-in configuration for YubiKey-backed sudo authentication. **Done via `gdca.yubikey.sudoMfa.enable`.**
- Add per-user registration helper for pam_u2f mapping. **Done via `yubikey-sudo-register`.**
- Keep disabled by default until recovery and backup key process is proven. **Done.**
- Test with fallback admin access before making this mandatory. **Done manually with both keys; helper added via `yubikey-sudo-test`.**

## Phase 4: PIV/smart-card macOS login

- Add documented PIV certificate provisioning flow. **Done for self-signed certificates via `yubikey-piv-login-setup`.**
- Pair the certificate with the local macOS user. **Supported explicitly with `yubikey-piv-login-setup --pair`; not automatic.**
- Verify login and screen unlock with fallback account/recovery procedure. **Done manually with both keys; status helper added via `yubikey-piv-login-status`.**
- Do not claim FileVault pre-boot YubiKey unlock support.

## Phase 4b: optional smart-card-only macOS login

- Add disabled opt-in configuration for macOS smart-card-only login. **Done via `gdca.yubikey.smartCardOnly.enable`; not enabled by default or for this host.**
- Add a guard that refuses to apply when fewer than two local smart-card pairings exist. **Done via `gdca.yubikey.smartCardOnly.minimumPairings`.**
- Add read-only policy status reporting. **Done via `yubikey-smartcard-policy-status`.**
- Document rollback and recovery requirements. **Done in `docs/yubikey-smartcard-only.md`.**

## Phase 5: operational policy

- Define lost-key, new-machine, and key-rotation procedures. **Done in `docs/yubikey-operations.md`.**
- Define recovery-key escrow process for FileVault. **Done in `docs/yubikey-operations.md`; FileVault remains password/recovery-key based.**
- Define whether one or two enrolled keys are mandatory before enforcement. **Done: primary and backup are required before sudo/login enforcement.**
- Add checks that report compliance without silently locking users out. **Done via `yubikey-policy-check`; it reports local state only and makes no auth changes.**
