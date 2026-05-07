# macOS Privacy Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend low-risk macOS privacy/security automation from the NBTV/Bazzell-style checklist, using nix-darwin where stable and the helper script otherwise.

**Architecture:** Keep declarative, stable per-user defaults in `modules/darwin/security.nix`. Keep privileged and runtime system changes in `scripts/macos-privacy-check.sh`, with focused helper functions for applying and checking settings. Add shell tests with command stubs so behavior is verified without mutating the host.

**Tech Stack:** Bash, macOS command-line tools (`defaults`, `systemsetup`, `networksetup`, `launchctl`, `socketfilterfw`), nix-darwin Nix modules, shell integration tests.

---

## File structure

- Modify `modules/darwin/security.nix`: add stable CustomUserPreferences for Handoff, Wi-Fi prompts, Spotlight improvement sharing, notification privacy, Siri/Apple Intelligence, analytics/ads.
- Modify `scripts/macos-privacy-check.sh`: add apply/check helpers for firewall auto-allow flags, Wi-Fi prompts, Bluetooth, Handoff, expanded analytics, Spotlight, notifications, NTP, and outbound firewall detection.
- Create `tests/macos-privacy-check-apply-expanded-hardening.test.sh`: verifies `--apply` issues the intended low-risk commands through stubs.
- Create `tests/macos-privacy-check-expanded-report.test.sh`: verifies report recognizes hardened settings through stubs.
- Modify `README.md`: document newly automated settings and remaining manual items.

---

### Task 1: Add failing test for expanded `--apply` command intent

**Files:**
- Create: `tests/macos-privacy-check-apply-expanded-hardening.test.sh`
- Modify later: `scripts/macos-privacy-check.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/macos-privacy-check-apply-expanded-hardening.test.sh` with executable shell content that stubs privileged commands and records invocations:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/macos-privacy-check.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
log="$tmpdir/calls.log"
touch "$log"

make_stub() {
  local name="$1"
  cat >"$tmpdir/$name" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALL_LOG"
case "$(basename "$0")" in
  id)
    if [[ "${1:-}" == "-u" && $# -eq 1 ]]; then printf '0\n'; elif [[ "${1:-}" == "-u" ]]; then printf '501\n'; else /usr/bin/id "$@"; fi ;;
  stat)
    if [[ "${1:-}" == "-f" ]]; then printf 'alice\n'; else /usr/bin/stat "$@"; fi ;;
  launchctl)
    if [[ "${1:-}" == "asuser" ]]; then shift 2; exec "$@"; fi; exit 0 ;;
  sudo)
    if [[ "${1:-}" == "-u" ]]; then shift 2; exec "$@"; fi; exec "$@" ;;
  defaults|systemsetup|networksetup|blueutil|socketfilterfw|spctl|fdesetup|killall)
    exit 0 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$tmpdir/$name"
}

for cmd in id stat launchctl sudo defaults systemsetup networksetup blueutil socketfilterfw spctl fdesetup killall; do
  make_stub "$cmd"
done

CALL_LOG="$log" PATH="$tmpdir:$PATH" "$script" --apply >/dev/null

require_call() {
  local needle="$1"
  if ! grep -Fq "$needle" "$log"; then
    printf 'Recorded calls:\n' >&2
    cat "$log" >&2
    fail "expected call: $needle"
  fi
}

require_call 'socketfilterfw --setglobalstate on'
require_call 'socketfilterfw --setstealthmode on'
require_call 'socketfilterfw --setallowsigned off'
require_call 'socketfilterfw --setallowsignedapp off'
require_call 'networksetup -setairportpower'
require_call 'defaults write com.apple.airport.preferences AskToJoinMode DoNotAsk'
require_call 'defaults write com.apple.airport.preferences AskToJoinHotspot -bool false'
require_call 'blueutil --power 0'
require_call 'defaults write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false'
require_call 'defaults write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false'
require_call 'systemsetup -setusingnetworktime on'
require_call 'systemsetup -setnetworktimeserver pool.ntp.org'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
chmod +x tests/macos-privacy-check-apply-expanded-hardening.test.sh
tests/macos-privacy-check-apply-expanded-hardening.test.sh
```

Expected: FAIL because calls such as `socketfilterfw --setallowsigned off`, `blueutil --power 0`, and NTP commands are not implemented yet.

---

### Task 2: Implement expanded low-risk apply actions

**Files:**
- Modify: `scripts/macos-privacy-check.sh`
- Test: `tests/macos-privacy-check-apply-expanded-hardening.test.sh`

- [ ] **Step 1: Add helper functions after `read_console_default`**

Add helpers that tolerate absent optional tools while still keeping the script low-risk:

```bash
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

apply_console_default() {
  as_console_user defaults write "$@"
}
```

- [ ] **Step 2: Extend `apply_settings` firewall block**

After stealth mode, add:

```bash
  run_sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off >/dev/null 2>&1 || true
  run_sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off >/dev/null 2>&1 || true
```

- [ ] **Step 3: Add Wi-Fi, Bluetooth, Handoff, notification, Spotlight, Apple Intelligence, and NTP apply blocks**

Add these low-risk blocks inside `apply_settings` before FileVault handling:

```bash
  apply_msg "Disable Wi-Fi auto-join prompts"
  apply_console_default com.apple.airport.preferences AskToJoinMode DoNotAsk
  apply_console_default com.apple.airport.preferences AskToJoinHotspot -bool false
  networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}' | while read -r device; do
    [[ -n "$device" ]] && run_sudo networksetup -setairportpower "$device" off >/dev/null 2>&1 || true
  done

  apply_msg "Disable Bluetooth"
  if command_exists blueutil; then
    run_sudo blueutil --power 0 >/dev/null 2>&1 || true
  else
    skip "Bluetooth power control requires blueutil; install it if Bluetooth must be disabled by script"
  fi

  apply_msg "Disable Handoff"
  apply_console_default com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
  apply_console_default com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
  apply_console_default NSGlobalDomain AppleEnableMouseSwipeNavigateWithScrolls -bool false

  apply_msg "Reduce notification exposure"
  apply_console_default com.apple.ncprefs content_visibility -int 0
  apply_console_default com.apple.ncprefs show_on_lock_screen -bool false
  apply_console_default com.apple.ncprefs show_in_carplay -bool false
  apply_console_default com.apple.ncprefs summaries_enabled -bool false

  apply_msg "Disable Spotlight improvement sharing"
  apply_console_default com.apple.assistant.support Search Queries Data Sharing Status -int 2
  apply_console_default com.apple.Spotlight SuggestionsEnabled -bool false

  apply_msg "Disable Apple Intelligence where scriptable"
  apply_console_default com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false
  apply_console_default com.apple.assistant.support "Assistant Enabled" -bool false

  apply_msg "Use network time with pool.ntp.org"
  run_sudo systemsetup -setusingnetworktime on >/dev/null 2>&1 || true
  run_sudo systemsetup -setnetworktimeserver pool.ntp.org >/dev/null 2>&1 || true
```

- [ ] **Step 4: Run the apply-intent test**

Run:

```bash
tests/macos-privacy-check-apply-expanded-hardening.test.sh
```

Expected: PASS.

---

### Task 3: Add failing report test for expanded hardened settings

**Files:**
- Create: `tests/macos-privacy-check-expanded-report.test.sh`
- Modify later: `scripts/macos-privacy-check.sh`

- [ ] **Step 1: Write the failing test**

Create a shell test with stubs for `defaults`, `systemsetup`, `blueutil`, and `socketfilterfw` that return hardened state and assert report output contains:

```text
[OK] Firewall does not automatically allow built-in signed software
[OK] Firewall does not automatically allow downloaded signed software
[OK] Wi-Fi ask-to-join networks disabled
[OK] Wi-Fi ask-to-join hotspots disabled
[OK] Bluetooth disabled
[OK] Handoff disabled
[OK] Spotlight improvement sharing disabled
[OK] Network time server is pool.ntp.org
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
chmod +x tests/macos-privacy-check-expanded-report.test.sh
tests/macos-privacy-check-expanded-report.test.sh
```

Expected: FAIL because these report sections do not exist yet.

---

### Task 4: Implement expanded report sections

**Files:**
- Modify: `scripts/macos-privacy-check.sh`
- Test: `tests/macos-privacy-check-expanded-report.test.sh`

- [ ] **Step 1: Extend Firewall report**

Read:

```bash
firewall_allowsigned_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null || true)"
firewall_allowsignedapp_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsignedapp 2>/dev/null || true)"
```

Report OK when outputs contain `disabled`, `off`, or `not`.

- [ ] **Step 2: Add Wi-Fi/Bluetooth report**

Use `read_console_default com.apple.airport.preferences AskToJoinMode`, `read_console_default com.apple.airport.preferences AskToJoinHotspot`, and `blueutil --power` if available. Report Bluetooth as manual/check if `blueutil` is unavailable.

- [ ] **Step 3: Add Handoff, Spotlight, and Date/Time report**

Use console defaults for Handoff and Spotlight. Use `systemsetup -getusingnetworktime` and `systemsetup -getnetworktimeserver` for NTP.

- [ ] **Step 4: Run report test**

Run:

```bash
tests/macos-privacy-check-expanded-report.test.sh
```

Expected: PASS.

---

### Task 5: Add nix-darwin declarative defaults

**Files:**
- Modify: `modules/darwin/security.nix`

- [ ] **Step 1: Add stable CustomUserPreferences**

Add preferences mirroring script-safe user defaults where nix-darwin is appropriate:

```nix
    "com.apple.airport.preferences" = {
      AskToJoinMode = "DoNotAsk";
      AskToJoinHotspot = false;
    };

    "com.apple.coreservices.useractivityd" = {
      ActivityAdvertisingAllowed = false;
      ActivityReceivingAllowed = false;
    };

    "com.apple.assistant.support" = {
      "Assistant Enabled" = false;
      "Search Queries Data Sharing Status" = 2;
    };

    "com.apple.Siri" = {
      StatusMenuVisible = false;
      UserHasDeclinedEnable = true;
    };

    "com.apple.Spotlight" = {
      SuggestionsEnabled = false;
    };

    "com.apple.ncprefs" = {
      content_visibility = 0;
      show_on_lock_screen = false;
      show_in_carplay = false;
      summaries_enabled = false;
    };
```

- [ ] **Step 2: Validate Nix syntax**

Run:

```bash
nix flake check --no-build
```

Expected: no Nix syntax/evaluation errors. If this repo's flake does not support `--no-build`, run `nix flake check`.

---

### Task 6: Update README documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update Privacy / security section**

Document that the helper now applies/checks firewall signed auto-allow settings, Wi-Fi prompts, Bluetooth if `blueutil` exists, Handoff, AirDrop, Sharing, Siri/Apple Intelligence best-effort defaults, Spotlight improvement sharing, analytics/ads, and network time server.

- [ ] **Step 2: Keep manual list accurate**

Document that Apple ID/iCloud, Location Services, TCC app permissions, per-app Siri permissions, protected per-app notification settings, and outbound firewall installation remain manual/check-only.

---

### Task 7: Run full verification

**Files:**
- Test all changed behavior.

- [ ] **Step 1: Run all shell tests**

Run:

```bash
tests/macos-privacy-check-apply-expanded-hardening.test.sh && \
tests/macos-privacy-check-expanded-report.test.sh && \
tests/macos-privacy-check-console-user-defaults.test.sh && \
tests/macos-privacy-check-sharing-disabled-format.test.sh && \
tests/macos-privacy-check-usage.test.sh && \
tests/macos-privacy-check-apply-sudo.test.sh && \
tests/macos-privacy-check.test.sh
```

Expected: all tests exit 0.

- [ ] **Step 2: Run Nix validation**

Run:

```bash
nix flake check --no-build || nix flake check
```

Expected: no syntax/evaluation failures caused by `modules/darwin/security.nix`.

---

## Self-review

- Spec coverage: every approved setting category is covered by a task, either applied/reported or documented manual/check-only.
- Placeholder scan: no TBD/TODO placeholders remain.
- Scope check: LuLu/Homebrew, MDM profiles, Raycast replacement, and full Spotlight disable are intentionally out of scope.
