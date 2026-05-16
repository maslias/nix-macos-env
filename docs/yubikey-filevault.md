# YubiKey FileVault unlock discovery

This repo does **not** currently enable FileVault smart-card/YubiKey unlock.

Current production state on `gdca-maintaince`:

- macOS login/unlock: smart-card-only with paired YubiKeys
- sudo: YubiKey touch-only MFA plus normal auth stack
- FileVault pre-boot unlock: password/recovery-key based

## Why this is separate

FileVault unlock happens before the normal macOS login session. A mistake can block boot before normal shell-based recovery is available. FileVault smart-card behavior depends on macOS version, hardware, SecureToken/volume ownership state, FileVault user authorization, smart-card pairing, and recovery-key escrow.

## Read-only discovery

Run:

```sh
yubikey-filevault-status
```

To query a specific smart-card public-key hash:

```sh
yubikey-filevault-status --hash HASH
```

This helper runs read-only checks only:

- `fdesetup status`
- `sysadminctl -secureTokenStatus USER`
- `dscl` reads for GeneratedUID and smart-card token identities
- `diskutil apfs listUsers /`
- `sc_auth list -u USER`
- `sc_auth identities`
- `sc_auth filevault -o status -u USER [-h HASH]`

It does not enable, disable, or modify FileVault, smart-card pairings, PAM, login policy, or YubiKeys.

## Observed discovery note

On this machine, initial read-only `sc_auth filevault` status returned:

```text
SecureToken for user mliebreich is needed and is not present
```

Other read-only checks show the user has SecureToken and appears as an APFS cryptographic user/volume owner. Do not proceed to enablement until this mismatch is understood. It may indicate that `sc_auth filevault` expects additional FileVault authorization state, has limited support on this macOS/hardware combination, or behaves differently when smart-card-only login is already enforced.

## Preconditions before any future enable attempt

Before running any FileVault smart-card enable command:

1. Confirm FileVault recovery key is escrowed outside this Mac.
2. Confirm recovery key retrieval has been tested.
3. Confirm macOS Recovery can be reached.
4. Confirm at least one alternate admin/recovery path exists.
5. Confirm primary and backup YubiKeys both work for macOS smart-card login.
6. Confirm `yubikey-filevault-status` output is understood.
7. Confirm `sudo fdesetup list` shows the intended user as FileVault-authorized.
8. Confirm the exact `sc_auth filevault -o enable ...` command to run and rollback path.

## Explicit non-goals for now

- No declarative Nix enablement for FileVault smart-card unlock.
- No automatic `sc_auth filevault -o enable` execution.
- No changes to YubiKey PIV certificates for FileVault.
- No assumption that FileVault can be unlocked without the password/recovery-key path.
