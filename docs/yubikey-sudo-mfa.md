# YubiKey sudo MFA

This repo supports optional YubiKey-backed sudo MFA with `pam_u2f`.

Module default state: **disabled**. The `gdca-maintaince` host opts in after manual validation with both enrolled YubiKeys.

## What sudo MFA means

When enabled, `sudo` requires a registered YubiKey before the normal sudo authentication stack continues. The module default requires FIDO2 PIN verification, but the validated `gdca-maintaince` host uses touch-only YubiKey sudo MFA for lower daily friction:

```nix
gdca.yubikey.sudoMfa.pinVerification = false;
```

Touch-only sudo MFA still requires the registered physical YubiKey and normal sudo authentication; it does not make sudo passwordless.

This does not replace:

- macOS login password
- FileVault password/recovery key
- backup admin/recovery access

## Safe rollout order

1. Enroll the primary key:

   ```sh
   yubikey-enroll --role primary
   ```

2. Harden the primary key:

   ```sh
   yubikey-harden
   ```

3. Register the primary key for sudo MFA:

   ```sh
   yubikey-sudo-register
   ```

4. Repeat enrollment, hardening, and sudo registration for a second physical key:

   ```sh
   yubikey-enroll --role backup
   yubikey-harden
   yubikey-sudo-register
   ```

5. Check readiness:

   ```sh
   yubikey-status
   ```

6. Only after backup/recovery is validated for that host, opt in with Nix:

   ```nix
   gdca.yubikey.sudoMfa.enable = true;
   # Optional: touch-only YubiKey factor instead of FIDO2 PIN + touch.
   gdca.yubikey.sudoMfa.pinVerification = false;
   ```

## Testing after enabling

Keep one existing administrator shell open. In a second terminal, test with the helper:

```sh
yubikey-sudo-test
```

Or manually:

```sh
sudo -k
sudo -v
```

Expected behavior:

- sudo asks for YubiKey/FIDO interaction
- with touch-only policy, touch the YubiKey if it blinks
- with `pinVerification = true`, enter the FIDO2 PIN when prompted
- normal sudo authentication then continues

For check-only diagnostics without running sudo:

```sh
yubikey-sudo-test --check-only
```

If the test fails, use the still-open administrator shell to disable:

```nix
gdca.yubikey.sudoMfa.enable = false;
```

then apply the config again.

## Files

Per-user pam_u2f mappings live at:

```text
~/.config/Yubico/u2f_keys
```

Treat this as authentication configuration. It is not a password, but do not publish it unnecessarily.
