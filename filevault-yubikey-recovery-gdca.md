# FileVault/YubiKey Recovery Guide for `Gdca`

This guide is for recovering a Mac where FileVault pre-boot login no longer accepts the normal password or YubiKey after attempting FileVault smart-card/YubiKey setup.

The most important recovery path is the RecoveryOS command:

```sh
security filevault skip-sc-enforcement DATA_VOLUME_UUID set
```

That command asks FileVault to skip smart-card enforcement for one login. Use it before deleting files or reinstalling macOS.

> **Do not erase or reinstall macOS yet.** If the normal system volume is mounted but you cannot find `com.apple.security.smartcard.plist` or `ConfigurationProfiles`, you may be looking at the read-only system volume instead of the writable Data volume, or the relevant FileVault smart-card state may not be stored as a normal plist file.

---

## 1. Boot into RecoveryOS

1. Shut down the Mac.
2. Boot into RecoveryOS:
   - Apple Silicon: hold the power button until startup options appear, then choose **Options**.
   - Intel Mac: hold `Command + R` during boot.
3. Open **Utilities → Terminal**.

---

## 2. Check mounted volumes

In Recovery Terminal, run:

```sh
ls -la /Volumes
```

You may see two similarly named volumes, for example:

```text
Gdca
Gdca datas
```

or:

```text
Gdca
Gdca - Data
```

Usually:

- `Gdca` is the sealed/read-only system volume.
- `Gdca datas`, `Gdca Data`, or `Gdca - Data` is the writable Data volume.

For file searches, prefer the **Data** volume.

---

## 3. If needed, unlock/mount the Data volume

If the Data volume is already mounted, you do **not** need `diskutil apfs unlockVolume`.

If it is not mounted, list APFS volumes:

```sh
diskutil apfs list
```

Find the Data volume identifier, such as `disk3s5`, then unlock it:

```sh
diskutil apfs unlockVolume diskXsY
```

When prompted, try one of these:

- your FileVault recovery key, or
- the password of a FileVault-enabled local admin user.

Then check again:

```sh
ls -la /Volumes
```

---

## 4. Find the Data volume UUID

The FileVault smart-card bypass command needs the APFS Data volume UUID.

First identify the exact mounted Data volume name:

```sh
ls -la /Volumes
```

Then run `diskutil info` against that path. Adjust the path if your mounted volume has a different name:

```sh
diskutil info "/Volumes/Gdca datas" | grep -i "Volume UUID"
```

Other common examples:

```sh
diskutil info "/Volumes/Gdca - Data" | grep -i "Volume UUID"
diskutil info "/Volumes/Gdca Data" | grep -i "Volume UUID"
```

Copy the UUID. It should look like this:

```text
XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

---

## 5. Set the FileVault smart-card one-login bypass

In RecoveryOS Terminal, run:

```sh
security filevault skip-sc-enforcement DATA_VOLUME_UUID set
```

Replace `DATA_VOLUME_UUID` with the UUID from the previous step.

Example:

```sh
security filevault skip-sc-enforcement XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX set
```

Check the status:

```sh
security filevault skip-sc-enforcement DATA_VOLUME_UUID status
```

Then reboot:

```sh
reboot
```

Try logging in with the normal user password.

---

## 6. After a successful boot, disable FileVault smart-card binding

If the bypass lets you boot, disable the FileVault smart-card binding from the normal macOS session.

List paired smart-card identities:

```sh
sc_auth list -u "$USER"
```

Check FileVault smart-card status:

```sh
/usr/sbin/sc_auth filevault -o status -u "$USER"
```

If status output shows a YubiKey public-key hash enabled for FileVault, disable it:

```sh
sudo /usr/sbin/sc_auth filevault -o disable -u "$USER" -h HASH
```

Replace `HASH` with the YubiKey public-key hash shown by `sc_auth`.

Then check status again:

```sh
/usr/sbin/sc_auth filevault -o status -u "$USER"
```

---

## 7. Optional: search the Data volume for smart-card policy files

The expected plist name is:

```text
com.apple.security.smartcard.plist
```

not:

```text
com.apple.security.plist
```

Search the Data volume, not only the system volume. Adjust the path to the exact mounted Data volume name:

```sh
find "/Volumes/Gdca datas" -name 'com.apple.security.smartcard.plist' -print
```

If found, prefer renaming it instead of deleting it:

```sh
mv "/Volumes/Gdca datas/Library/Preferences/com.apple.security.smartcard.plist" \
   "/Volumes/Gdca datas/Library/Preferences/com.apple.security.smartcard.plist.disabled"
```

Also check possible configuration profile locations:

```sh
ls -la "/Volumes/Gdca datas/private/var/db/ConfigurationProfiles"
ls -la "/Volumes/Gdca datas/var/db/ConfigurationProfiles"
```

Search for related filenames:

```sh
find "/Volumes/Gdca datas" \( \
  -iname '*smartcard*' -o \
  -iname '*smart-card*' -o \
  -iname '*yubikey*' -o \
  -iname '*yubi*' -o \
  -iname '*piv*' \
\) -print
```

Do **not** blindly delete the entire `ConfigurationProfiles` directory unless you are comfortable removing local profile state. If the Mac is managed by MDM, deleting local profile files may be ineffective or may cause management issues.

---

## 8. If the bypass command fails

If this command fails:

```sh
security filevault skip-sc-enforcement DATA_VOLUME_UUID set
```

try Apple's Recovery password tool:

```sh
resetpassword
```

Follow the prompts and see whether it offers to unlock or reset credentials for the FileVault volume.

If neither the FileVault recovery key nor an authorized local admin password can unlock the Data volume, the issue is deeper than a smart-card preference file.

---

## Quick command summary

Adjust `Gdca datas` and `DATA_VOLUME_UUID` for the actual names on the Mac.

```sh
# RecoveryOS Terminal
ls -la /Volumes

diskutil apfs list

# Only if the Data volume is not already mounted:
diskutil apfs unlockVolume diskXsY

# Find Data volume UUID:
diskutil info "/Volumes/Gdca datas" | grep -i "Volume UUID"

# One-login FileVault smart-card bypass:
security filevault skip-sc-enforcement DATA_VOLUME_UUID set
security filevault skip-sc-enforcement DATA_VOLUME_UUID status

reboot
```

After successful normal boot:

```sh
sc_auth list -u "$USER"
/usr/sbin/sc_auth filevault -o status -u "$USER"
sudo /usr/sbin/sc_auth filevault -o disable -u "$USER" -h HASH
/usr/sbin/sc_auth filevault -o status -u "$USER"
```
