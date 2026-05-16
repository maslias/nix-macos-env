# Workstation setup instructions

Use this guide to set up a macOS workstation with this repo.

## 1. Prepare the repo

Edit `flake.nix` and set:

```nix
username = "your-macos-short-username";
hostname = "your-hostname";
```

For the validated machine this is currently:

```nix
username = "mliebreich";
hostname = "gdca-maintaince";
```

## 2. Apply the base system

From the repo root:

```sh
./scripts/setup.sh
```

This installs/applies nix-darwin and Home Manager. It also runs a safe YubiKey enrollment/status step.

Useful skip flags:

```sh
./scripts/setup.sh --skip-yubikey
./scripts/setup.sh --skip-privacy
```

After the first setup, normal rebuilds can use:

```sh
sudo darwin-rebuild switch --flake .#gdca-maintaince
```

Replace `gdca-maintaince` with your configured hostname.

## 3. Guided YubiKey setup

For a new workstation or new primary/backup keys, run:

```sh
yubikey-workstation-setup
```

This wizard guides:

- primary key enrollment
- backup key enrollment
- YubiKey hardening
- sudo MFA registration
- PIV smart-card login pairing
- final status checks

It pauses before each sensitive step.

For known serials:

```sh
yubikey-workstation-setup \
  --primary-serial 31021632 \
  --backup-serial 31021618
```

## 4. Validate YubiKey state

Run:

```sh
yubikey-status
yubikey-policy-check --require-piv-pairings 2
yubikey-smartcard-policy-status --require-pairings 2
```

Expected on the validated host:

- primary key enrolled
- backup key enrolled
- sudo MFA registered
- two PIV pairings present
- smart-card-only login enabled

## 5. Validate sudo

Keep an admin shell open, then run:

```sh
sudo -k
sudo -v
```

Expected on the validated host:

- YubiKey touch is required
- FIDO2 PIN is not required for sudo
- PIV PIN may still be requested by macOS smart-card authentication

## 6. Validate login/unlock

Test before relying on the machine:

1. Lock screen.
2. Unlock with primary YubiKey PIV PIN.
3. Lock screen again.
4. Unlock with backup YubiKey PIV PIN.
5. Confirm password-only unlock without a YubiKey is not accepted on smart-card-only hosts.

## 7. Existing-key rotation

For existing configured keys, use:

```sh
yubikey-workstation-rotate
```

Safe default rotation can guide:

- PIV PIN rotation
- PIV PUK rotation
- protected management-key rotation
- sudo MFA re-registration
- pairing/status checks

Destructive PIV key/certificate replacement is not default. Only use this when planned:

```sh
yubikey-workstation-rotate --replace-piv-identity
```

## 8. FileVault

Current policy:

- FileVault remains password/recovery-key based.
- YubiKey FileVault unlock is not enabled.

Read-only discovery only:

```sh
yubikey-filevault-status
```

Do not run FileVault smart-card enable commands unless the documented blocker is resolved.

## 9. Validate power policy

Run:

```sh
power-status
```

Expected policy:

- plugged into power: system/display/disk sleep disabled
- on battery: system/display/disk sleep after 15 minutes

For external monitors, macOS shows login/unlock on the active/main display. The config keeps AC sleep disabled for docked use, but display arrangement/main-display selection remains a macOS setting.

## 10. Emergency rollback notes

Disable smart-card-only login preference from an open admin shell:

```sh
yubikey-smartcard-policy-disable
```

Then disable this in Nix before rebuilding if needed:

```nix
gdca.yubikey.smartCardOnly.enable = false;
```

Keep FileVault recovery keys escrowed outside the Mac.
