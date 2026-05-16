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

## Observed discovery and blocker

On this machine, `sc_auth filevault` status returns the same error with and without `sudo`, for both paired YubiKey public-key hashes:

```sh
sudo /usr/sbin/sc_auth filevault -o status -u "$USER" -h 299A66FA60D26D3EF35383B190362290A1C6A345
sudo /usr/sbin/sc_auth filevault -o status -u "$USER" -h 81996693D9C672D509867641795BDA68D65F13D5
```

```text
SecureToken for user mliebreich is needed and is not present
```

Other read-only checks contradict that message:

```text
sysadminctl -secureTokenStatus mliebreich
  Secure token is ENABLED for user mliebreich

sudo fdesetup list
  mliebreich,9DB1DCA0-9B6A-464F-94A3-32853C5E2987

diskutil apfs listUsers /
  9DB1DCA0-9B6A-464F-94A3-32853C5E2987
  Type: Local Open Directory User
  Volume Owner: Yes
```

`dscl` also shows both smart-card token identities in `AuthenticationAuthority`.

Conclusion for this Mac: FileVault smart-card/YubiKey unlock is **blocked** for the local `sc_auth filevault` + self-signed PIV path. Do not run `sc_auth filevault -o enable` unless Apple/MDM/platform-specific guidance explains and resolves this mismatch.

Possible future investigation paths:

- Apple enterprise/MDM-supported smart-card FileVault workflow
- internal CA-issued PIV certificates instead of self-signed certificates
- macOS/hardware-specific behavior differences
- Apple support/documentation for FileVault, SecureToken, volume ownership, and smart cards on Apple Silicon

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
