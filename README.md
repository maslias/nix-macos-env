# macOS Nix setup

A small `nix-darwin` repo for learning Nix step by step.

Current focus: minimal macOS system appearance.

Machine-specific values live in `flake.nix`:

- `username`: your macOS short username
- `hostname`: your desired host/computer name

## Structure

```text
flake.nix                         # flake inputs and darwin configuration
hosts/default.nix                 # generic host config, uses flake hostname
modules/darwin/nix.nix            # minimal Nix settings
modules/darwin/packages.nix       # system packages, empty for now
modules/darwin/macos-defaults.nix # Dock, Finder, desktop/widgets
modules/darwin/security.nix       # firewall and low-risk privacy defaults
modules/darwin/raycast.nix        # Raycast package and Spotlight shortcut handoff
modules/darwin/alacritty.nix      # Alacritty terminal package and config
modules/darwin/zsh.nix            # shared zsh defaults
modules/darwin/vim.nix            # minimal Vim setup
modules/darwin/system.nix         # required nix-darwin system basics
users/default.nix                 # macOS user path, parameterized by flake username
scripts/setup.sh                  # small nix-darwin bootstrap/apply helper
```

## What is configured now

### Dock

- auto-hide Dock
- hide recent apps
- do not reorder Spaces
- smaller Dock icons
- keep Dock at the bottom

### Finder

- show file extensions
- keep hidden files hidden
- show path bar
- show status bar
- use column view by default

### Desktop / widgets

- screenshots go to `~/Pictures/Screenshots`
- clicking wallpaper does not reveal desktop
- desktop widgets are hidden

### Raycast

- install Raycast from nixpkgs
- allow only Raycast as an unfree nixpkgs package
- disable macOS Spotlight shortcuts so `Cmd-Space` can be used for Raycast

Suggested Raycast hotkeys to set manually in Raycast Settings:

| Action | Suggested hotkey | Notes |
| --- | --- | --- |
| Show Raycast | `Cmd-Space` | Replaces Spotlight; no repo conflict after applying this config. |
| Window: Left Half | `Cmd-Control-H` | Vim-style and avoids macOS `Cmd-Option-H` / “Hide Others”. |
| Window: Right Half | `Cmd-Control-L` | Low-conflict Vim-style binding. |
| Window: Top Half | `Cmd-Control-K` | Low-conflict Vim-style binding. |
| Window: Bottom Half | `Cmd-Control-J` | Low-conflict Vim-style binding. |
| Window: Maximize | `Cmd-Control-M` | Prefer Raycast “Maximize” over macOS “Toggle Fullscreen” for tiling workflows. |
| Open Alacritty | `Cmd-Enter` | Add as an app hotkey or Raycast Quicklink/script command. |
| Open Terminal.app | `Cmd-Shift-Enter` | Add as an app hotkey or Raycast Quicklink/script command. |

Avoided alternative: `Cmd-Option-H/J/K/L/M`. It is close to your original idea, but `Cmd-Option-H` conflicts with the common macOS/app “Hide Others” shortcut.

Raycast Window Management needs macOS Accessibility permission on first use.

### Terminal

- install Alacritty
- manage `~/.config/alacritty/alacritty.toml` declaratively
- use stable Menlo font defaults
- set `TERM=xterm-256color` for broad compatibility
- enable macOS Option-as-Alt behavior
- add modest window padding, clipboard selection, hidden mouse while typing, and a dark Nord-style palette

### Zsh

- enable zsh through nix-darwin
- keep 10,000 history entries
- share history between terminal sessions
- ignore commands starting with a space
- reduce duplicate history entries
- enable case-insensitive completion
- enable completion menu selection
- add `fzf` with zsh keybinds/completion and clean default UI
- add zsh completions, autosuggestions, syntax highlighting, and fzf-tab
- use Oh My Zsh `ssh-agent` plugin
- enable vi editing mode
- add `Ctrl-p` / `Ctrl-n` prefix history search
- disable terminal bell
- allow comments in interactive commands

### Vim

- install Vim
- enable syntax highlighting and filetype indentation
- use 2-space indentation for config files
- show line numbers and relative line numbers
- improve search defaults
- add EditorConfig support

### Privacy / security

Nix-managed where stable:

- enable macOS application firewall
- enable firewall stealth mode
- reduce Apple personalized ads
- reduce diagnostics / analytics sharing
- disable Wi-Fi ask-to-join prompts and hotspot prompts
- disable Handoff defaults
- disable Siri prompts/menu state where scriptable
- disable Apple search / Siri improvement sharing where scriptable
- reduce notification exposure on lock screen and summaries where scriptable
- disable Spotlight suggestion/improvement sharing

Helper-script managed because it needs imperative macOS commands or root/runtime state:

- disable firewall automatic allow rules for built-in signed software and downloaded signed apps
- disable common sharing services
- disable AirDrop
- disable Bluetooth if `blueutil` is installed
- disable Wi-Fi radio and prompts where available
- apply Siri, Apple Intelligence, analytics, ads, Handoff, notification, and Spotlight privacy defaults for the console user
- disable Spotlight indexing and erase the existing Spotlight index
- keep network time enabled and set the server to `pool.ntp.org`
- check FileVault and optionally start Apple's interactive FileVault enablement
- check whether LuLu or Little Snitch is installed for outbound firewall control

Not forced automatically:

- Gatekeeper: team policy decision, because it trades safety against Apple dependency
- Apple ID / iCloud Drive / iCloud Keychain / Photos sync decisions
- Location Services global and per-app permissions
- Camera, Microphone, Accessibility, Full Disk Access, Screen Recording, Contacts, Calendars, and other TCC permissions
- per-app Siri permissions and protected per-app notification permissions
- installing/configuring a third-party outbound firewall such as LuLu or Little Snitch

Helper command after applying the Nix config:

```sh
macos-privacy-check
```

The source script lives at:

```sh
scripts/macos-privacy-check.sh
```

It reports firewall, FileVault, Gatekeeper, sharing services, AirDrop, Siri, analytics/ads, and manual review items.

## Configure

Set the machine-specific values in `flake.nix`:

```nix
let
  username = "your-macos-short-username";
  hostname = "your-hostname";
in
```

The `hosts/default.nix` and `users/default.nix` modules are generic and consume those values from the flake.

## Apply

First install Nix. Then run the lightweight setup script:

```sh
./scripts/setup.sh
```

Or run nix-darwin directly, replacing the flake attribute with your configured hostname:

```sh
nix run nix-darwin -- switch --flake .#your-hostname
```

After first bootstrap:

```sh
darwin-rebuild switch --flake .#your-hostname
```

## Suggestions for next small additions

- Keyboard: faster key repeat and disable press-and-hold accents.
- Trackpad: tap-to-click and natural scrolling preferences.
- Packages: install a tiny base set like `git`, `vim`, `curl`.
- Homebrew: manage cask apps declaratively later, if needed.
