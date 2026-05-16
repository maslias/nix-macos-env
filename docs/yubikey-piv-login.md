# YubiKey PIV / macOS smart-card login

This phase prepares YubiKeys for macOS smart-card login using the PIV applet.

Default state: **not enforced**.

## Current implementation

The helper:

```sh
yubikey-piv-login-setup
```

creates a self-signed PIV authentication certificate on the inserted YubiKey.

Defaults:

- PIV slot: `9a` / PIV Authentication
- key algorithm: RSA 2048 for broad macOS smart-card compatibility
- PIN policy: once
- touch policy: never (macOS pairing/login compatibility; PIN is still required)
- certificate: self-signed

It does not force smart-card-only login.

## Prepare a key

With one YubiKey inserted:

```sh
yubikey-piv-login-setup
```

If slot `9a` already contains a certificate and you intentionally want to replace it:

```sh
yubikey-piv-login-setup --force
```

If an earlier ECC certificate was created but `sc_auth identities` stays empty, recreate with the RSA default:

```sh
yubikey-piv-login-setup --force
```

If pairing fails with CryptoTokenKit / SmartCard error `6982`, recreate with the current default touch policy (`never`):

```sh
yubikey-piv-login-setup --force
```

Use `--force` carefully because it overwrites PIV slot material.

## Pair with the local macOS user

Pairing is explicit:

```sh
yubikey-piv-login-setup --pair
```

The helper prints `sc_auth identities`. Copy the public-key hash for the new YubiKey identity when prompted. It then runs:

```sh
sudo sc_auth pair -u "$USER" -h HASH
```

Verify pairings:

```sh
sc_auth list -u "$USER"
```

Or use the status helper:

```sh
yubikey-piv-login-status
```

## Recovery rules

## Validated behavior

The intended baseline is:

- primary YubiKey unlock works with PIV PIN
- backup YubiKey unlock works with PIV PIN
- Touch ID can still work where macOS allows it
- macOS password fallback still works when no YubiKey is inserted

Do not enforce smart-card-only login until all are true:

- primary YubiKey works for login/unlock
- backup YubiKey works for login/unlock
- sudo MFA works with both keys
- FileVault recovery key is escrowed
- a break-glass admin/recovery path is tested

## FileVault note

`sc_auth` has FileVault-related subcommands on macOS, but this repo still treats FileVault as password/recovery-key based until separately validated. Do not assume YubiKey-only FileVault unlock.
