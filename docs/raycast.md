# Raycast defaults

Raycast is installed by `modules/darwin/raycast.nix`, and nix-darwin disables the macOS Spotlight shortcuts so `Cmd-Space` can be used by Raycast.

Raycast itself does **not** expose a stable Home Manager/nix-darwin module for command hotkeys. Its supported portable format is an encrypted `.rayconfig` export, imported through Raycast's own **Import Settings & Data** command.

## Desired baseline hotkeys

Set these in Raycast, then export a clean seed config:

| Action | Hotkey | Notes |
| --- | --- | --- |
| Show Raycast | `Cmd-Space` | Spotlight is disabled by nix-darwin. |
| Window Management: Left Half | `Cmd-Control-H` | Vim-style left. |
| Window Management: Right Half | `Cmd-Control-L` | Vim-style right. |
| Window Management: Top Half | `Cmd-Control-K` | Vim-style up. |
| Window Management: Bottom Half | `Cmd-Control-J` | Vim-style down. |
| Window Management: Maximize | `Cmd-Control-M` | Tiling maximize, not macOS fullscreen. |
| Open Alacritty | `Cmd-Enter` | Assign to the Alacritty app entry in Raycast, or to a script command. |

Optional additions worth considering:

| Action | Hotkey |
| --- | --- |
| Window Management: Center | `Cmd-Control-C` |
| Window Management: Almost Maximize | `Cmd-Control-F` |
| Window Management: Previous Display | `Cmd-Control-Shift-H` |
| Window Management: Next Display | `Cmd-Control-Shift-L` |
| Open Terminal.app fallback | `Cmd-Shift-Enter` |

Avoid `Cmd-Option-H` because it conflicts with the common macOS/app **Hide Others** shortcut.

## Create a clean seed `.rayconfig`

Do this once on a clean Raycast profile, ideally a temporary macOS user, so the export does not include personal clipboard history, notes, AI chats, etc.

1. Launch Raycast.
2. Skip sign-in/cloud sync unless you intentionally want account state in the seed.
3. Configure the hotkeys above in Raycast Settings.
4. If using Window Management, run one window command once and grant Accessibility permission.
5. Run Raycast command **Export Settings & Data**.
6. Set an export passphrase of at least 8 characters and store it in your password manager.
7. Save the file as one of:
   - `assets/raycast/default.rayconfig` if it is safe to commit,
   - `secrets/raycast/default.rayconfig` if kept locally/untracked,
   - `~/.config/raycast/default.rayconfig` if managed outside this repo.

Raycast exports are encrypted, but a committed seed should still be treated as configuration data. Do not commit a personal backup unless you are comfortable with the repository containing that encrypted data.

## Import / bootstrap on a machine

Use the helper:

```sh
scripts/raycast-import-settings.sh path/to/default.rayconfig
```

If no path is given, it looks for:

1. `assets/raycast/default.rayconfig`
2. `secrets/raycast/default.rayconfig`
3. `~/.config/raycast/default.rayconfig`

The script opens Raycast and the `.rayconfig` file. Raycast will still ask for the passphrase and import categories. For this repo, normally select only:

- **Settings, Aliases & Hotkeys**
- **Window Management Layouts**
- optionally **Extensions installed from the Store** if the seed intentionally includes them

Do not select personal categories from a backup unless you want to merge them into this machine.

## Why not write Raycast files directly?

Current Raycast versions store most state in `~/Library/Application Support/com.raycast.macos/raycast-enc.sqlite`, an internal encrypted database. Direct SQLite/plist mutation is unstable and risks corrupting user data. The `.rayconfig` import path is supported by Raycast and includes hotkeys, aliases, installed extensions, and window management layouts.
