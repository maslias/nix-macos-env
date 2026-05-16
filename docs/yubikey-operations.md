# YubiKey operational procedures

This document covers day-2 operations for the workstation YubiKey setup.

Safety boundaries:

- Do not enable smart-card-only login unless separately approved and tested with primary key, backup key, and recovery access.
- Do not depend on YubiKey-only FileVault pre-boot unlock.
- Keep macOS password fallback and FileVault recovery access available unless a separate policy changes that.
- Keep at least one tested backup administrator or recovery path before changing sudo/login authentication.

## Baseline policy

For each admin/operator user on a protected Mac:

1. Enroll one primary YubiKey.
2. Enroll one backup YubiKey.
3. Harden both keys:
   - default PIV PIN changed
   - default PIV PUK changed
   - default PIV management key replaced/protected
   - FIDO2 PIN set
4. Register both keys for sudo MFA with `yubikey-sudo-register`.
5. Pair both keys for macOS PIV/smart-card login if smart-card unlock is desired.
6. Verify:
   - sudo MFA works with primary and backup keys
   - screen unlock works with primary and backup PIV PINs
   - macOS password fallback still works
   - FileVault recovery key is escrowed outside the Mac

Run the local policy report:

```sh
yubikey-policy-check
```

If PIV login is required for the workstation, also check for at least two local pairings:

```sh
yubikey-policy-check --require-piv-pairings 2
```

The policy check reports local state only. It does not change YubiKeys, PAM, macOS login, FileVault, or smart-card policy.

## New machine procedure

1. Apply the Nix config with YubiKey tooling installed.
2. Enroll the primary key:

   ```sh
   yubikey-enroll --role primary
   ```

3. Enroll the backup key:

   ```sh
   yubikey-enroll --role backup
   ```

4. Check or perform hardening for both physical keys:

   ```sh
   yubikey-harden --check-only
   yubikey-harden
   ```

5. Register each key for sudo MFA:

   ```sh
   yubikey-sudo-register
   ```

6. If PIV unlock is desired, provision/pair each key:

   ```sh
   yubikey-piv-login-setup --pair
   ```

7. Validate primary and backup keys:

   ```sh
   yubikey-status
   yubikey-policy-check --require-piv-pairings 2
   yubikey-sudo-test
   yubikey-piv-login-status
   ```

8. Only after validation, enable host-specific sudo MFA if it is not already enabled for that host.

## Lost key procedure

If a YubiKey is lost or suspected compromised:

1. Use the remaining backup key or password fallback to sign in.
2. Keep an administrator shell available before changing auth configuration.
3. Remove the lost key's pam_u2f credential from `~/.config/Yubico/u2f_keys`.
   - The current helper appends credentials; removal is a manual edit.
   - Preserve credentials for keys that should remain valid.
4. Remove the lost key's macOS smart-card pairing with `sc_auth unpair` or the relevant macOS smart-card management flow.
5. Mark the key lost in the organization's asset/credential inventory.
6. Enroll and harden a replacement backup key.
7. Register and test the replacement key for sudo MFA.
8. Pair and test the replacement key for PIV unlock if used.
9. Re-run:

   ```sh
   yubikey-status
   yubikey-policy-check --require-piv-pairings 2
   yubikey-sudo-test
   ```

Do not remove the only working key or only working admin path before the replacement is validated.

## Key rotation procedure

Use this for planned replacement or certificate refresh:

1. Confirm the old primary and old backup both still work.
2. Prepare the new key with `yubikey-enroll --role backup` or `--role primary` as appropriate.
3. Run `yubikey-harden` on the new key.
4. Run `yubikey-sudo-register` for the new key.
5. Run `yubikey-piv-login-setup --pair` if PIV unlock is used.
6. Test sudo and screen unlock with the new key.
7. Only after successful testing, remove old pam_u2f credentials and old PIV pairings.
8. Update asset inventory and the local enrollment inventory as needed.

## FileVault recovery-key escrow

FileVault remains password/recovery-key based in this repo.

Minimum operational expectation:

- FileVault recovery key is stored outside the Mac in the approved secret store or MDM escrow.
- At least two authorized operators know how to retrieve it.
- Recovery retrieval is tested during onboarding and after major policy changes.
- YubiKey PIV/smart-card pairing is not treated as a FileVault pre-boot unlock solution.

## Enforcement policy

`gdca.yubikey.sudoMfa.enable = true` should be host-specific, not a blanket default for unvalidated machines.

Before enabling sudo MFA on a host, confirm:

- primary key enrolled, hardened, registered, and tested
- backup key enrolled, hardened, registered, and tested
- password/recovery/admin fallback tested
- recovery steps documented for the operator

Smart-card-only login is available only as a disabled opt-in. Before enabling it, read `docs/yubikey-smartcard-only.md`, validate both PIV pairings, and keep recovery/admin access available. FileVault smart-card unlock still requires separate design, approval, and hands-on validation.
