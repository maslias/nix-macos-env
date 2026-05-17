# YubiKey / FileVault Recovery Guide

Situation: after reboot, macOS shows a normal-looking username/password login screen. YubiKey PIV PIN and normal password do not unlock.

This repository currently enables macOS smart-card-only login:

```nix
gdca.yubikey.smartCardOnly.enable = true;
```

That removes normal password-only fallback for macOS login/unlock. However, this repo does **not** automatically enable or validate FileVault YubiKey/PIV unlock. FileVault pre-boot unlock is normally still password/recovery-key based.

## Key idea

The first screen after reboot can be the **FileVault pre-boot unlock screen**, even if it looks like the usual macOS login screen.

At FileVault pre-boot, the expected credential is usually:

- your macOS account password, or
- the FileVault personal recovery key

Usually **not** the YubiKey PIV PIN, unless FileVault smart-card unlock was explicitly enabled and tested.

## Step 1: Try password carefully

At the first screen after reboot, try:

1. current macOS user password
2. previous macOS user password, if it was changed recently
3. check Caps Lock
4. check keyboard layout
5. if your password has special characters, try the layout that FileVault may be using, often US or system default
6. if possible, try an external USB keyboard

Tip: if the screen has a username field, you can briefly type the password there to verify which characters are produced, then erase it.

## Step 2: If account password does not work, use FileVault recovery key

If password fails, use the FileVault personal recovery key.

On Apple Silicon:

1. Shut down the Mac.
2. Hold the power button until **Options** appears.
3. Open **Options / Recovery**.
4. Unlock the disk with the FileVault recovery key if prompted.
5. Open **Utilities → Terminal**.

## Step 3: Remove smart-card-only enforcement from Recovery

In Recovery Terminal, list mounted volumes:

```sh
ls /Volumes
```

Find the smart-card preference file:

```sh
find /Volumes -path '*Library/Preferences/com.apple.security.smartcard.plist' -print
```

Remove the found file. Common examples:

```sh
rm "/Volumes/Macintosh HD - Data/Library/Preferences/com.apple.security.smartcard.plist"
```

or:

```sh
rm "/Volumes/Macintosh HD/Library/Preferences/com.apple.security.smartcard.plist"
```

Then reboot:

```sh
reboot
```

This should remove `enforceSmartCard` and may restore password login, assuming FileVault itself can be unlocked.

## Step 4: If you can log into macOS

Immediately disable smart-card-only policy from a normal terminal:

```sh
sudo defaults delete /Library/Preferences/com.apple.security.smartcard enforceSmartCard
```

or use the helper from this repo/Nix environment:

```sh
yubikey-smartcard-policy-disable
```

Then edit `flake.nix` and change:

```nix
gdca.yubikey.smartCardOnly.enable = true;
```

to:

```nix
gdca.yubikey.smartCardOnly.enable = false;
```

Then rebuild the nix-darwin system.

## Step 5: Verify state after recovery

Once logged in, run:

```sh
sc_auth list -u "$USER"
sc_auth identities
yubikey-piv-login-status
yubikey-smartcard-policy-status --require-pairings 2
yubikey-filevault-status
```

Check whether FileVault smart-card unlock was ever enabled:

```sh
/usr/sbin/sc_auth filevault -o status -u "$USER"
```

## Important warning

Lock-screen YubiKey/PIV unlock working does **not** prove reboot/FileVault unlock works.

There are two separate authentication stages:

1. **FileVault pre-boot unlock** — usually password/recovery-key based.
2. **macOS login/unlock** — affected by `enforceSmartCard` and YubiKey/PIV pairing.

Do not re-enable smart-card-only login until all of these are true:

- primary YubiKey works for macOS login/unlock
- backup YubiKey works for macOS login/unlock
- FileVault recovery key is known and stored outside the Mac
- RecoveryOS boot was tested
- another admin/recovery path exists
- full reboot behavior was tested safely
- FileVault smart-card behavior is understood and intentionally configured

Recommended safe setting for now:

```nix
gdca.yubikey.smartCardOnly.enable = false;
gdca.yubikey.sudoMfa.enable = true;
```
