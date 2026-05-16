# macOS Nix setup

A small `nix-darwin` repo for learning Nix step by step.

Current focus: minimal macOS system appearance.

Machine-specific values live in `flake.nix`:

- `username`: your macOS short username
- `hostname`: your desired host/computer name

## Structure

```text
flake.nix                         # flake inputs and darwin/home-manager configuration
hosts/default.nix                 # generic host config, uses flake hostname
home/default.nix                  # Home Manager user config
home/starship.nix                 # Starship prompt with Cyberdream colors
home/nvim.nix                     # Neovim with offline-safe native LSP, completion, Treesitter, fzf-lua
home/tmux.nix                     # tmux config in ~/.config/tmux/tmux.conf
home/vim.nix                      # user Vim config in ~/.config/vim/vimrc
home/zsh.nix                      # user zsh config in ~/.config/zsh/.zshrc
modules/darwin/nix.nix            # minimal Nix settings
modules/darwin/rosetta.nix        # Rosetta 2 for x86_64 binaries on Apple Silicon
modules/darwin/packages.nix       # shared CLI packages and helper scripts
modules/darwin/macos-defaults.nix # Dock, Finder, desktop/widgets
modules/darwin/power.nix          # AC/battery sleep and Low Power Mode settings
modules/darwin/security.nix       # firewall and low-risk privacy defaults
modules/darwin/yubikey.nix        # YubiKey tooling and check helper
modules/darwin/raycast.nix        # Raycast package and Spotlight shortcut handoff
modules/darwin/alacritty.nix      # Alacritty terminal package and config
modules/darwin/zsh.nix            # global zsh bootstrap for ZDOTDIR
modules/darwin/system.nix         # required nix-darwin system basics
users/default.nix                 # macOS user path, parameterized by flake username
scripts/setup.sh                  # small nix-darwin bootstrap/apply helper
scripts/yubikey-check.sh          # YubiKey tooling/device visibility check
scripts/yubikey-enroll.sh         # local YubiKey enrollment inventory helper
scripts/yubikey-harden.sh         # interactive PIN/PUK/FIDO hardening helper
scripts/yubikey-status.sh         # YubiKey inventory/readiness status helper
scripts/yubikey-sudo-register.sh  # pam_u2f sudo MFA registration helper
scripts/yubikey-sudo-test.sh      # guided sudo MFA validation helper
scripts/yubikey-piv-login-setup.sh # PIV smart-card login preparation helper
scripts/yubikey-piv-login-status.sh # PIV smart-card login status helper
scripts/yubikey-smartcard-policy-status.sh # smart-card-only policy status helper
```

## What is configured now

### Rosetta

- install Rosetta 2 on Apple Silicon Macs for x86_64 binary compatibility
- declare `x86_64-darwin` as an extra Nix platform alongside `aarch64-darwin`

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

### Login window

- show username and password fields instead of selectable user icons

### Raycast

- install Raycast from nixpkgs
- allow only explicitly listed unfree nixpkgs apps: Google Chrome, Raycast, and VS Code
- disable macOS Spotlight shortcuts so `Cmd-Space` can be used for Raycast

Suggested Raycast hotkeys to set manually in Raycast Settings, or seed once via Raycast's `.rayconfig` import flow documented in [`docs/raycast.md`](docs/raycast.md):

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

### Keybinding strategy

This repo keeps keybindings small, mnemonic, and macOS-aware. The main rule is:

```text
Ctrl-h/j/k/l   move inside the current workspace: Vim/Neovim splits and tmux panes
Ctrl-, / Ctrl-. move between tmux windows without using the tmux prefix
Space ...      Neovim/Vim editor commands
Ctrl-b ...     tmux management commands
zsh vi mode    shell editing
```

Custom cross-tool bindings intentionally avoid `Cmd-*`, `Option/Alt-*`, and `Ctrl-Arrow` because those commonly conflict with macOS, terminal apps, text navigation, Mission Control/Spaces, or Raycast. The only listed `Alt-*` binding is fzf's standard shell-local `Alt-c` widget.

#### Shared navigation

| Binding | Context | Action |
| --- | --- | --- |
| `Ctrl-h` | Vim, Neovim, tmux | move to left split/pane |
| `Ctrl-j` | Vim, Neovim, tmux | move to lower split/pane |
| `Ctrl-k` | Vim, Neovim, tmux | move to upper split/pane |
| `Ctrl-l` | Vim, Neovim, tmux | move to right split/pane |
| `Ctrl-,` | tmux in Alacritty | previous window |
| `Ctrl-.` | tmux in Alacritty | next window |

`Ctrl-,` and `Ctrl-.` are the validated tmux window-navigation bindings for this setup. Alacritty emits xterm `modifyOtherKeys` sequences for these punctuation chords, and tmux parses them as `C-,` / `C-.`. This avoids macOS `Cmd-*`, `Option/Alt-*`, unreliable `Ctrl-Shift-*` terminal chords, and `Ctrl-Arrow` Mission Control/text-navigation conflicts while still providing prefix-free tmux window navigation.

#### Vim / Neovim editor basics

| Binding | Action |
| --- | --- |
| `Space w` | save/update current buffer |
| `Space q` | quit current window |
| `Esc` | clear search highlight |

#### Neovim groups

| Binding | Action |
| --- | --- |
| `Space f f` | find files |
| `Space f g` | live grep |
| `Space f b` | find buffers |
| `Space f h` | find help |
| `Space f k` | find keymaps |
| `Space f s` | document symbols |
| `Space f r` | LSP references picker |
| `Space f d` | document diagnostics picker |
| `Space c a` | code action |
| `Space c r` | rename symbol |
| `Space c f` | format buffer |
| `Space d d` | line diagnostics |
| `Space d l` | diagnostics to location list |
| `Space s r` | split right |
| `Space s d` | split down |
| `Space s x` | close split |

Native LSP-style motions are kept: `gd` definition, `gD` declaration, `gi` implementation, `gr` references, and `K` hover.

#### tmux management

| Binding | Action |
| --- | --- |
| `Ctrl-b r` | reload tmux config |
| `Ctrl-b :` | tmux command prompt |
| `Ctrl-b c` | new window in current path |
| `Ctrl-b %` | split right in current path |
| `Ctrl-b "` | split down in current path |
| `Ctrl-b h/j/k/l` | select pane |
| `Ctrl-b H/J/K/L` | resize pane |
| `Ctrl-b S` / `Ctrl-b R` | save / restore tmux session |
| `Ctrl-b P` | toggle pane logging |
| `Ctrl-b G` | capture screen |
| `Ctrl-b A` | save complete pane history |
| `Ctrl-b X` | clear pane history |

#### zsh / fzf

| Binding | Action |
| --- | --- |
| vi insert/normal mode | shell editing model |
| `Ctrl-r` | fuzzy history search |
| `Ctrl-t` | fuzzy file insert |
| `Alt-c` | fuzzy `cd` from fzf default bindings |
| `Ctrl-y` | accept autosuggestion / fzf selection |
| `Ctrl-p` / `Ctrl-n` | prefix history search backward / forward |
| `Ctrl-x Ctrl-e` | edit command line in `$EDITOR` |
| `v` in zsh normal mode | edit command line in `$EDITOR` |

To bootstrap Raycast settings from an exported seed file:

```sh
scripts/raycast-import-settings.sh path/to/default.rayconfig
```

### Terminal

- install Alacritty
- install JetBrainsMono Nerd Font for terminal glyph/icon support
- manage `~/.config/alacritty/alacritty.toml` declaratively
- add a matching Terminal.app `Cyberdream` profile and make it the default/startup profile
- use Cyberdream dark colors from `cyberdream.nvim` extras
- use a comfortable 14pt terminal font size
- set `TERM=xterm-256color` for broad compatibility
- enable macOS Option-as-Alt behavior
- add modest window padding, clipboard selection, and hidden mouse while typing

### Neovim

- install Neovim through Home Manager while keeping Vim as the default user editor
- use native Neovim 0.12 LSP and completion, without Mason or runtime downloads
- install LSP servers and tools through Nix for bash, YAML, Nix, TOML, JSON, and Python
- add Nix-managed Treesitter parsers, local SchemaStore data, Cyberdream colors, mini.statusline, mini.bracketed, and fzf-lua
- provide shared LSP, diagnostic, format, and fuzzy-finder keybindings

### Shell prompt

- install and enable Starship through Home Manager
- use the same Cyberdream colors as Alacritty
- show hostname, full path, git branch/status, and optional Devbox marker
- show command duration on the right after 5 seconds
- use a two-line prompt with a yellow success `❯` and red error `❯`

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

### GUI apps

- install VS Code

### CLI packages

- install Git
- install ripgrep (`rg`)
- install fd (`fd`)
- install bat (`bat`)
- install tldr (`tldr`)
- install YubiKey tooling (`ykman`, `yubico-piv-tool`, `opensc-tool`, `fido2-token`, `pamu2fcfg`), `yubikey-check`, `yubikey-enroll`, `yubikey-harden`, `yubikey-status`, `yubikey-sudo-register`, `yubikey-sudo-test`, `yubikey-piv-login-setup`, and `yubikey-piv-login-status`

### Vim

- install Vim
- enable syntax highlighting and filetype indentation
- use 2-space indentation for config files
- show line numbers and relative line numbers
- improve search defaults
- add EditorConfig support

### Power

- on AC power, disable computer sleep, display sleep, and disk sleep
- on battery, sleep/display-sleep/disk-sleep after 15 minutes idle
- enable macOS Low Power Mode on battery when supported
- disable macOS screensaver globally; battery display sleep handles the 15-minute battery behavior

### YubiKey

- install YubiKey/FIDO/PIV tooling through `modules/darwin/yubikey.nix`
- run `yubikey-enroll` by default from `scripts/setup.sh` after the nix-darwin switch
- report `yubikey-status` readiness after enrollment
- allow bypassing the YubiKey step with `scripts/setup.sh --skip-yubikey`
- record local YubiKey enrollment inventory in `~/.config/nix-macos/yubikeys.tsv`
- support primary/backup key role tracking with `yubikey-enroll --role primary|backup`
- provide `yubikey-harden` to interactively change default PIV PIN/PUK/management key and set a FIDO2 PIN
- provide `yubikey-status` to report inventory, inserted-key hardening, and readiness for future enforcement
- provide `yubikey-sudo-register` to create the per-user pam_u2f mapping for sudo MFA
- provide `yubikey-sudo-test` for guided sudo MFA validation
- keep sudo MFA opt-in with `gdca.yubikey.sudoMfa.enable = true` after backup/recovery validation
- provide `yubikey-piv-login-setup` to create a self-signed RSA PIV certificate and optionally pair it for macOS smart-card login
- provide `yubikey-piv-login-status` to report smart-card identities, pairings, and FileVault smart-card status
- provide `yubikey-policy-check` to report local operational-policy compliance without changing auth settings
- provide `yubikey-smartcard-policy-status` to report smart-card-only login policy state without changing auth settings
- include host-specific smart-card-only login enforcement with a pairing-count guard for validated hosts; not enabled by module default
- do not implement FileVault YubiKey unlock in the current phase

See [`docs/yubikey.md`](docs/yubikey.md), [`docs/yubikey-sudo-mfa.md`](docs/yubikey-sudo-mfa.md), [`docs/yubikey-piv-login.md`](docs/yubikey-piv-login.md), [`docs/yubikey-smartcard-only.md`](docs/yubikey-smartcard-only.md), [`docs/yubikey-operations.md`](docs/yubikey-operations.md), and [`docs/yubikey-plan.md`](docs/yubikey-plan.md).

### Privacy / security

Nix-managed where stable:

- enable Touch ID / Apple Watch authentication for `sudo` where supported
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

Run the setup script. If Nix is missing, it installs Determinate Nix first, copies the repo to the canonical location `~/.config/nix-macos` when needed, applies nix-darwin with Home Manager enabled, then runs mandatory privacy hardening with `macos-privacy-check --apply`:

```sh
./scripts/setup.sh
```

To skip the mandatory privacy hardening only for debugging or recovery:

```sh
./scripts/setup.sh --skip-privacy
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
- Packages: add more daily CLI tools as needed, such as `curl`, `jq`, or `eza`.
- Homebrew: manage cask apps declaratively later, if needed.
