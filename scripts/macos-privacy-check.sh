#!/usr/bin/env bash
set -euo pipefail

# Check and optionally apply low-risk macOS privacy/security defaults.
# Usage:
#   macos-privacy-check                 # report only
#   macos-privacy-check --apply         # apply automatable defaults, then report
#   macos-privacy-check --apply --enable-filevault
#   macos-privacy-check --apply --gatekeeper enable|disable|skip

info() { printf '\n==> %s\n' "$*"; }
ok() { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [CHECK] %s\n' "$*"; }
manual() { printf '  [MANUAL] %s\n' "$*"; }
apply_msg() { printf '  [APPLY] %s\n' "$*"; }
skip() { printf '  [SKIP] %s\n' "$*"; }

apply=false
enable_filevault=false
gatekeeper_policy="skip"
SOCKETFILTERFW="${SOCKETFILTERFW:-/usr/libexec/ApplicationFirewall/socketfilterfw}"

usage() {
  sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) apply=true ;;
    --enable-filevault) enable_filevault=true ;;
    --gatekeeper)
      shift
      gatekeeper_policy="${1:-}"
      case "$gatekeeper_policy" in enable|disable|skip) ;; *) usage; exit 2 ;; esac
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
  shift
done

bool_status() {
  case "${1:-}" in
    1|true|yes|on) echo "enabled" ;;
    0|false|no|off) echo "disabled" ;;
    *) echo "unknown" ;;
  esac
}

require_sudo_credentials() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi

  if ! sudo -n true >/dev/null 2>&1; then
    warn "Administrator credentials are required for --apply. Run this script from an interactive terminal after sudo -v, or run it with sudo."
    exit 1
  fi
}

run_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo -n "$@"
  fi
}

as_console_user() {
  local user uid
  user="$(stat -f '%Su' /dev/console 2>/dev/null || id -un)"
  uid="$(id -u "$user" 2>/dev/null || id -u)"

  if [[ "$(id -u)" -eq 0 && "$user" != "root" ]]; then
    launchctl asuser "$uid" sudo -u "$user" "$@"
  else
    "$@"
  fi
}

kill_if_running() {
  killall "$1" >/dev/null 2>&1 || true
}

read_console_default() {
  as_console_user defaults read "$@" 2>/dev/null || echo unknown
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

apply_console_default() {
  as_console_user defaults write "$@"
}

apply_settings() {
  require_sudo_credentials

  info "Applying automatable privacy/security defaults"

  apply_msg "Enable Application Firewall and stealth mode"
  run_sudo "$SOCKETFILTERFW" --setglobalstate on >/dev/null
  run_sudo "$SOCKETFILTERFW" --setstealthmode on >/dev/null
  run_sudo "$SOCKETFILTERFW" --setallowsigned off >/dev/null 2>&1 || true
  run_sudo "$SOCKETFILTERFW" --setallowsignedapp off >/dev/null 2>&1 || true

  case "$gatekeeper_policy" in
    enable)
      apply_msg "Enable Gatekeeper"
      run_sudo spctl --master-enable
      ;;
    disable)
      apply_msg "Disable Gatekeeper"
      run_sudo spctl --master-disable
      ;;
    skip)
      skip "Gatekeeper left unchanged; pass --gatekeeper enable or --gatekeeper disable"
      ;;
  esac

  apply_msg "Disable common sharing services"
  run_sudo launchctl disable system/com.apple.screensharing 2>/dev/null || true
  run_sudo launchctl disable system/com.apple.AppleFileServer 2>/dev/null || true
  run_sudo launchctl disable system/com.apple.smbd 2>/dev/null || true
  run_sudo launchctl disable system/com.apple.RemoteDesktop.agent 2>/dev/null || true
  run_sudo launchctl disable system/com.apple.RemoteAppleEvents 2>/dev/null || true
  run_sudo systemsetup -setremoteappleevents off >/dev/null 2>&1 || true
  run_sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
    -deactivate -stop >/dev/null 2>&1 || true

  apply_msg "Disable AirDrop"
  apply_console_default com.apple.NetworkBrowser DisableAirDrop -bool true
  kill_if_running Finder

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

  apply_msg "Disable Siri and Apple Intelligence where scriptable"
  apply_console_default com.apple.assistant.support 'Assistant Enabled' -bool false
  apply_console_default com.apple.Siri StatusMenuVisible -bool false
  apply_console_default com.apple.Siri UserHasDeclinedEnable -bool true
  apply_console_default com.apple.CloudSubscriptionFeatures.optIn '545129924' -bool false

  apply_msg "Reduce notification exposure"
  apply_console_default com.apple.ncprefs content_visibility -int 0
  apply_console_default com.apple.ncprefs show_on_lock_screen -bool false
  apply_console_default com.apple.ncprefs show_in_carplay -bool false
  apply_console_default com.apple.ncprefs summaries_enabled -bool false

  apply_msg "Disable Spotlight improvement sharing and indexing"
  apply_console_default com.apple.assistant.support 'Search Queries Data Sharing Status' -int 2
  apply_console_default com.apple.Spotlight SuggestionsEnabled -bool false
  run_sudo mdutil -a -i off >/dev/null 2>&1 || true
  run_sudo mdutil -a -E >/dev/null 2>&1 || true

  apply_msg "Disable personalized ads and diagnostics auto-submit"
  apply_console_default com.apple.AdLib allowApplePersonalizedAdvertising -bool false
  apply_console_default com.apple.AdLib allowIdentifierForAdvertising -bool false
  apply_console_default com.apple.AdLib forceLimitAdTracking -bool true
  apply_console_default com.apple.SubmitDiagInfo AutoSubmit -bool false
  apply_console_default com.apple.SubmitDiagInfo AutoSubmitVersion -int 4
  apply_console_default com.apple.SubmitDiagInfo ThirdPartyDataSubmit -bool false
  apply_console_default com.apple.SubmitDiagInfo ThirdPartyDataSubmitVersion -int 4
  apply_console_default com.apple.assistant.support 'Siri Data Sharing Opt-In Status' -int 2

  apply_msg "Use network time with pool.ntp.org"
  run_sudo systemsetup -setusingnetworktime on >/dev/null 2>&1 || true
  run_sudo systemsetup -setnetworktimeserver pool.ntp.org >/dev/null 2>&1 || true

  if [[ "$enable_filevault" == true ]]; then
    apply_msg "Start interactive FileVault enablement"
    warn "This requires a local user password and will show/save a recovery key. Do not automate the secret entry."
    run_sudo fdesetup enable
  else
    skip "FileVault left unchanged; pass --enable-filevault for Apple's interactive flow"
  fi
}

if [[ "$apply" == true ]]; then
  apply_settings
fi

info "Firewall"
firewall_global_state="$($SOCKETFILTERFW --getglobalstate 2>/dev/null || true)"
firewall_stealth_state="$($SOCKETFILTERFW --getstealthmode 2>/dev/null || true)"
firewall_allowsigned_state="$($SOCKETFILTERFW --getallowsigned 2>/dev/null || true)"
firewall_allowsignedapp_state="$($SOCKETFILTERFW --getallowsignedapp 2>/dev/null || true)"
if [[ "$firewall_global_state" == *"enabled"* ]]; then
  ok "Application firewall enabled"
else
  warn "Application firewall not enabled"
fi

if [[ "$firewall_stealth_state" == *"enabled"* || "$firewall_stealth_state" == *"is on"* ]]; then
  ok "Stealth mode enabled"
else
  warn "Stealth mode not enabled"
fi

if [[ "${firewall_allowsigned_state,,}" =~ disabled|off|not ]]; then
  ok "Firewall does not automatically allow built-in signed software"
else
  warn "Firewall may automatically allow built-in signed software"
fi

if [[ "${firewall_allowsignedapp_state,,}" =~ disabled|off|not ]]; then
  ok "Firewall does not automatically allow downloaded signed software"
else
  warn "Firewall may automatically allow downloaded signed software"
fi

info "FileVault"
filevault_status="$(fdesetup status 2>/dev/null || true)"
if [[ "$filevault_status" == *"FileVault is On"* ]]; then
  ok "FileVault enabled"
else
  warn "FileVault not enabled or status unknown"
fi

info "Gatekeeper"
gatekeeper_status="$(spctl --status 2>/dev/null || true)"
printf '  %s\n' "$gatekeeper_status"
manual "Gatekeeper is intentionally a team policy decision: enabled = safer, disabled = less Apple dependency."

info "Sharing services"
for service in \
  com.apple.screensharing \
  com.apple.AppleFileServer \
  com.apple.smbd \
  com.apple.RemoteDesktop.agent \
  com.apple.RemoteAppleEvents; do
  if launchctl print-disabled system 2>/dev/null | grep -Eq '"'"$service"'" => (true|disabled)'; then
    ok "$service disabled"
  else
    warn "$service may be enabled or not managed"
  fi
done

info "AirDrop / Handoff"
airdrop_disabled="$(read_console_default com.apple.NetworkBrowser DisableAirDrop)"
handoff_advertising="$(read_console_default com.apple.coreservices.useractivityd ActivityAdvertisingAllowed)"
handoff_receiving="$(read_console_default com.apple.coreservices.useractivityd ActivityReceivingAllowed)"
if [[ "$airdrop_disabled" == "1" ]]; then
  ok "AirDrop disabled"
else
  warn "AirDrop not disabled or status unknown"
fi

if [[ "$handoff_advertising" == "0" && "$handoff_receiving" == "0" ]]; then
  ok "Handoff disabled"
else
  warn "Handoff not disabled or status unknown"
fi

info "Wi-Fi / Bluetooth"
wifi_ask_join="$(read_console_default com.apple.airport.preferences AskToJoinMode)"
wifi_ask_hotspot="$(read_console_default com.apple.airport.preferences AskToJoinHotspot)"
if [[ "$wifi_ask_join" == "DoNotAsk" ]]; then
  ok "Wi-Fi ask-to-join networks disabled"
else
  warn "Wi-Fi ask-to-join networks status unknown or enabled"
fi

if [[ "$wifi_ask_hotspot" == "0" || "$wifi_ask_hotspot" == "DoNotAsk" ]]; then
  ok "Wi-Fi ask-to-join hotspots disabled"
else
  warn "Wi-Fi ask-to-join hotspots status unknown or enabled"
fi

if command_exists blueutil; then
  bluetooth_power="$(blueutil --power 2>/dev/null || echo unknown)"
  if [[ "$bluetooth_power" == "0" ]]; then
    ok "Bluetooth disabled"
  else
    warn "Bluetooth status: $(bool_status "$bluetooth_power")"
  fi
else
  manual "Bluetooth status requires blueutil for script verification."
fi

info "Siri / Apple Intelligence"
siri_enabled="$(read_console_default com.apple.assistant.support 'Assistant Enabled')"
if [[ "$siri_enabled" == "0" ]]; then
  ok "Siri disabled"
else
  warn "Siri not disabled or status unknown"
fi

info "Spotlight"
spotlight_sharing="$(read_console_default com.apple.assistant.support 'Search Queries Data Sharing Status')"
spotlight_suggestions="$(read_console_default com.apple.Spotlight SuggestionsEnabled)"
spotlight_indexing="$(mdutil -a -s 2>/dev/null || true)"
if [[ "$spotlight_sharing" == "2" || "$spotlight_suggestions" == "0" ]]; then
  ok "Spotlight improvement sharing disabled"
else
  warn "Spotlight improvement sharing status unknown or enabled"
fi
if [[ "${spotlight_indexing,,}" == *"indexing disabled"* ]]; then
  ok "Spotlight indexing disabled"
else
  warn "Spotlight indexing may be enabled or status unknown"
fi

info "Notifications"
notification_lock_screen="$(read_console_default com.apple.ncprefs show_on_lock_screen)"
notification_summaries="$(read_console_default com.apple.ncprefs summaries_enabled)"
if [[ "$notification_lock_screen" == "0" ]]; then
  ok "Lock-screen notifications disabled where scriptable"
else
  warn "Lock-screen notifications status unknown or enabled"
fi
if [[ "$notification_summaries" == "0" ]]; then
  ok "Notification summaries disabled where scriptable"
else
  warn "Notification summaries status unknown or enabled"
fi
manual "Per-app notification permissions may be protected/private; review System Settings manually."

info "Analytics / ads"
personalized_ads="$(read_console_default com.apple.AdLib allowApplePersonalizedAdvertising)"
diag_submit="$(read_console_default com.apple.SubmitDiagInfo AutoSubmit)"
siri_data_sharing="$(read_console_default com.apple.assistant.support 'Siri Data Sharing Opt-In Status')"
if [[ "$personalized_ads" == "0" ]]; then
  ok "Personalized ads disabled"
else
  warn "Personalized ads status: $(bool_status "$personalized_ads")"
fi

if [[ "$diag_submit" == "0" ]]; then
  ok "Diagnostics auto-submit disabled"
else
  warn "Diagnostics auto-submit status: $(bool_status "$diag_submit")"
fi

if [[ "$siri_data_sharing" == "2" || "$siri_data_sharing" == "0" ]]; then
  ok "Siri/Apple Intelligence improvement sharing disabled where scriptable"
else
  warn "Siri/Apple Intelligence improvement sharing status unknown or enabled"
fi

info "Date / Time"
network_time_status="$(systemsetup -getusingnetworktime 2>/dev/null || true)"
network_time_server="$(systemsetup -getnetworktimeserver 2>/dev/null || true)"
if [[ "$network_time_status" == *"On"* ]]; then
  ok "Network time enabled"
else
  warn "Network time not enabled or status unknown"
fi
if [[ "$network_time_server" == *"pool.ntp.org"* ]]; then
  ok "Network time server is pool.ntp.org"
else
  warn "Network time server is not pool.ntp.org or status unknown"
fi

info "Outbound application firewall"
if [[ -d /Applications/LuLu.app || -d /Applications/Little\ Snitch.app ]]; then
  ok "Third-party outbound firewall app detected"
else
  manual "Consider LuLu or Little Snitch if outbound control is required."
fi

info "Manual privacy review"
manual "Apple ID / iCloud: decide whether to sign in, disable iCloud Drive/Keychain if needed."
manual "Location Services: review globally and per app in System Settings."
manual "App permissions/TCC: Camera, Microphone, Accessibility, Full Disk Access require user approval or MDM profiles."
manual "Notifications: disable sensitive previews or app notifications as needed."
manual "Third-party app firewall: consider LuLu or Little Snitch if outbound control is required."
