# YubiKey FileVault unlock discovery

This repo does **not** enable FileVault smart-card/YubiKey unlock automatically through Nix activation. After a real pre-boot lockout during testing, execute mode is blocked on hosts with macOS smart-card-only login enforced. Treat FileVault smart-card unlock as experimental and not production-ready in this repo.

Current production state on `gdca-maintaince`:

- macOS login/unlock: smart-card-only with paired YubiKeys
- sudo: YubiKey touch-only MFA plus normal auth stack
- FileVault pre-boot unlock: password/recovery-key based unless the guarded enable wizard is explicitly completed

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
- `diskutil info /System/Volumes/Data` for the APFS Data volume UUID
- `security filevault skip-sc-enforcement DATA_VOLUME_UUID status` when available; outside RecoveryOS this is expected to report that the command is Recovery-only
- `sc_auth list -u USER`
- `sc_auth identities`
- `sc_auth filevault -o status -u USER [-h HASH]`

It does not enable, disable, or modify FileVault, smart-card pairings, PAM, login policy, or YubiKeys.

## Guarded enable wizard

Run preflight only:

```sh
yubikey-filevault-enable --dry-run
```

If multiple paired hashes exist, pass the inserted key's hash explicitly:

```sh
yubikey-filevault-enable --dry-run --hash HASH
```

Run recovery/admin verification and record a local checkpoint:

```sh
yubikey-filevault-enable --verify-recovery --hash HASH
```

This checks sudo, local admin membership, FileVault authorization, and whether FileVault reports a personal recovery key. It still requires typed confirmations for the two things software cannot prove: that the recovery key is stored outside this Mac and that RecoveryOS boot was tested. The checkpoint is written to:

```text
~/.config/nix-macos/filevault-smartcard-recovery.tsv
```

Execute mode is intentionally blocked when macOS smart-card-only login is enforced. The previous enable attempt with slot 9a and 9d present did not produce a trustworthy status and caused a pre-boot lockout where YubiKey/PIV and user password were not accepted.

For future lab-only work, the enable command under investigation is:

```sh
/usr/sbin/sc_auth filevault -o enable -u "$USER" -h HASH
```

If preflight reports that slot 9d is missing, create a key-management certificate on the inserted key before retrying:

```sh
yubikey-piv-login-setup \
  --serial SERIAL \
  --slot 9d \
  --subject "CN=USER@HOST YubiKey SERIAL Key Management"
```

Do not use `--pair` for slot 9d; keep login pairing on slot 9a.

The guarded wizard now also refuses to claim success unless post-enable status confirms enablement. The observed status remained:

```text
SecureToken for user mliebreich is needed and is not present
```

Rollback for partial/ambiguous state is:

```sh
sudo /usr/sbin/sc_auth filevault -o disable -u "$USER" -h HASH
```

RecoveryOS observation from the failed test:

- The System volume `Gdca` could be unlocked with the FileVault recovery key.
- `Gdca - Data` had to be unlocked/mounted separately.
- `security filevault skip-sc-enforcement ... set` failed for the System volume UUID.
- The skip command was accepted for the Data volume UUID, but did not restore ordinary password unlock in that boot attempt.

Emergency one-login bypass from RecoveryOS, if smart-card enforcement blocks login, should target the Data volume UUID, but is not sufficient as the only recovery plan:

```sh
security filevault skip-sc-enforcement DATA_VOLUME_UUID set
```

## Current 2026 re-check

Apple's current deployment guide says FileVault smart-card unlock is supported on Apple silicon Macs with macOS 11 or later, including CCID/PIV-compatible smart cards. It also says T2 Macs do **not** support FileVault smart-card unlock; on T2, the supported pattern is password FileVault unlock followed by smart-card login, with `DisableFDEAutoLogin` set.

This workstation is on macOS 26.4.1 and still reports normal FileVault/SecureToken/volume-owner state:

- `fdesetup status`: FileVault is on
- `sysadminctl -secureTokenStatus mliebreich`: Secure token is enabled
- `diskutil apfs listUsers /`: the local user is a volume owner
- `sc_auth list -u mliebreich`: both YubiKey public-key hashes are paired

`sc_auth` remains a shell wrapper around CryptoTokenKit's `ctkbind` for FileVault operations:

```sh
/usr/sbin/sc_auth filevault -o status -u "$USER" -h HASH
# calls ctkbind -o fvstatus -u "$USER" -h HASH
```

The read-only FileVault smart-card status still returns this message for both paired YubiKey hashes:

```sh
/usr/sbin/sc_auth filevault -o status -u "$USER" -h 299A66FA60D26D3EF35383B190362290A1C6A345
/usr/sbin/sc_auth filevault -o status -u "$USER" -h 81996693D9C672D509867641795BDA68D65F13D5
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

Updated interpretation: this message is probably **not** the same SecureToken reported by `sysadminctl`. `ctkbind` appears to be reporting that the smart-card FileVault unlock token/wrapping state is not present yet. It may simply mean "FileVault smart-card unlock is not enabled for this user/hash" rather than "the macOS user lacks SecureToken."

However, enabling still crosses a pre-boot authentication boundary. Keep Nix activation read-only; use only the explicit guided wizard for a supervised enable test with a verified recovery path.

Possible future investigation paths:

- determine whether smart-card-only login must be disabled before FileVault smart-card experimentation
- determine why `sc_auth filevault -o enable` produced no error but post-status remained `SecureToken ... not present`
- determine whether self-signed 9a/9d certificates are insufficient and CA-issued certificates are required
- compare Apple's documentation statement that FileVault smart-card support can be managed using `security` with the local `security filevault` subcommands, which currently only expose RecoveryOS skip-enforcement operations
- internal CA-issued PIV certificates instead of self-signed certificates if self-signed PIV certificates fail the enable test
- Apple support/documentation for the exact meaning of `ctkbind`'s "SecureToken ... is not present" status text

## Preconditions before any future enable attempt

Before running any FileVault smart-card enable command:

1. Confirm FileVault recovery key is escrowed outside this Mac.
2. Confirm recovery key retrieval has been tested.
3. Confirm macOS Recovery can be reached.
4. Confirm at least one alternate admin/recovery path exists.
5. Confirm primary and backup YubiKeys both work for macOS smart-card login.
6. Confirm `yubikey-filevault-status` output is understood.
7. Confirm `sudo fdesetup list` shows the intended user as FileVault-authorized.
8. Disable macOS smart-card-only login before any future lab test, or use a disposable/test Mac.
9. Run `yubikey-filevault-enable --verify-recovery --hash HASH` and confirm it records a recent checkpoint.
10. Confirm the exact `sc_auth filevault -o enable ...` command to run as the logged-in user, not through `sudo`.
11. Confirm rollback/disable command: `sudo /usr/sbin/sc_auth filevault -o disable -u USER -h HASH`.
12. Confirm RecoveryOS can unlock both System and Data volumes and that recovery-key unlock works.

## Explicit non-goals for now

- No declarative Nix activation enablement for FileVault smart-card unlock.
- No unattended `sc_auth filevault -o enable` execution.
- No FileVault smart-card execute while smart-card-only login is enforced.
- No changes to YubiKey PIV certificates for FileVault.
- No assumption that FileVault can be unlocked without the password/recovery-key path.
