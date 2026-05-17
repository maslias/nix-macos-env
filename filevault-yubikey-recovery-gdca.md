# FileVault/YubiKey Smartcard Recovery Guide for Volume `Gdca`

This guide is for the situation where macOS FileVault login no longer accepts either your YubiKey or your user password after running a YubiKey/FileVault wizard or script.

The goal is to boot into RecoveryOS, unlock/mount the encrypted macOS Data volume named `Gdca`, remove or disable smartcard enforcement files if present, then reboot.

> **Important:** Do not erase or reinstall macOS yet. If `find /Volumes ... com.apple.security.smartcard.plist` returns nothing, the most likely reason is that the encrypted Data volume is not mounted/unlocked in RecoveryOS.

---

## 1. Boot into RecoveryOS

1. Shut down the Mac.
2. Boot into RecoveryOS:
   - Apple Silicon: hold the power button until startup options appear, then choose **Options**.
   - Intel Mac: hold `Command + R` during boot.
3. Open **Utilities → Terminal**.

---

## 2. Check what volumes are currently mounted

In Recovery Terminal, run:

```sh
ls -la /Volumes
```

If `Gdca` is not listed, or if only the system/recovery volumes are listed, the Data volume is probably still locked.

---

## 3. List APFS volumes

Run:

```sh
diskutil apfs list
```

Look for the APFS volume named:

```text
Gdca
```

Note its identifier. It will look something like:

```text
disk3s5
```

The exact identifier may be different on your machine.

---

## 4. Unlock and mount `Gdca`

Replace `diskXsY` below with the real identifier from the previous step:

```sh
diskutil apfs unlockVolume diskXsY
```

For example, if `Gdca` is `disk3s5`, run:

```sh
diskutil apfs unlockVolume disk3s5
```

When prompted, try one of these:

- your FileVault recovery key, or
- the password of a FileVault-enabled local admin user

After unlocking, check again:

```sh
ls -la /Volumes
```

You should see something like:

```text
Gdca
```

If it is mounted under a slightly different name, use that exact name in the commands below.

---

## 5. Search for the smartcard preference file

Once `Gdca` is mounted, run:

```sh
find /Volumes -path '*Library/Preferences/com.apple.security.smartcard.plist' -print
```

Or search only inside `Gdca`:

```sh
find "/Volumes/Gdca" -path '*Library/Preferences/com.apple.security.smartcard.plist' -print
```

If the file exists, you may see:

```text
/Volumes/Gdca/Library/Preferences/com.apple.security.smartcard.plist
```

---

## 6. Disable the smartcard preference file

Prefer renaming the file instead of deleting it, so it can be restored later if needed:

```sh
mv "/Volumes/Gdca/Library/Preferences/com.apple.security.smartcard.plist" "/Volumes/Gdca/Library/Preferences/com.apple.security.smartcard.plist.disabled"
```

If you are sure you want to delete it instead:

```sh
rm "/Volumes/Gdca/Library/Preferences/com.apple.security.smartcard.plist"
```

---

## 7. Check for configuration profiles that may enforce smartcard login

The YubiKey/FileVault wizard may have installed a configuration profile. If so, deleting only `com.apple.security.smartcard.plist` may not be enough because the setting can be regenerated.

Check for profile data:

```sh
ls -la "/Volumes/Gdca/var/db/ConfigurationProfiles"
```

Search for smartcard-related files:

```sh
find "/Volumes/Gdca/var/db/ConfigurationProfiles" \( -iname '*smart*' -o -iname '*card*' -o -iname '*yubi*' -o -iname '*piv*' \) -print
```

If obvious YubiKey/smartcard profile files are present, do **not** blindly delete the entire `ConfigurationProfiles` directory unless you are comfortable removing local configuration profile state. If the Mac is managed by MDM, deleting profile data may be ineffective or cause management issues.

A safer first step is to rename suspicious files/directories only if you are confident they relate to the smartcard policy.

---

## 8. Search more broadly for smartcard policy files

Run:

```sh
find "/Volumes/Gdca" -name 'com.apple.security.smartcard.plist' -print
```

You can also search for YubiKey/PIV/smartcard references:

```sh
find "/Volumes/Gdca" \( -iname '*smartcard*' -o -iname '*smart-card*' -o -iname '*yubikey*' -o -iname '*yubi*' -o -iname '*piv*' \) -print
```

This may produce many results. Focus on system preference/profile locations, especially:

```text
/Volumes/Gdca/Library/Preferences
/Volumes/Gdca/var/db/ConfigurationProfiles
```

---

## 9. Reboot

After disabling the smartcard preference file, reboot:

```sh
reboot
```

Then try logging in with the normal user password.

---

## 10. If `Gdca` cannot be unlocked

If this command fails:

```sh
diskutil apfs unlockVolume diskXsY
```

and neither your user password nor FileVault recovery key works, try the Recovery password reset tool:

```sh
resetpassword
```

Follow the prompts and see whether it offers to unlock or reset credentials for the FileVault volume.

If `resetpassword` cannot help and the volume cannot be unlocked, the issue is deeper than the smartcard preference file.

---

## Quick command summary

```sh
ls -la /Volumes

diskutil apfs list

# Replace diskXsY with the identifier for Gdca
diskutil apfs unlockVolume diskXsY

ls -la /Volumes

find "/Volumes/Gdca" -path '*Library/Preferences/com.apple.security.smartcard.plist' -print

mv "/Volumes/Gdca/Library/Preferences/com.apple.security.smartcard.plist" "/Volumes/Gdca/Library/Preferences/com.apple.security.smartcard.plist.disabled"

find "/Volumes/Gdca/var/db/ConfigurationProfiles" \( -iname '*smart*' -o -iname '*card*' -o -iname '*yubi*' -o -iname '*piv*' \) -print

reboot
```
