#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: power-status [options]

Reports macOS power settings relevant to this workstation policy.
This command does not change power settings.

Policy expected by this repo:
  - AC power: sleep/display/disk sleep disabled
  - Battery: sleep/display/disk sleep after 15 minutes

Options:
  -h, --help   Show this help
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
fi

failures=0

check_value() {
  local profile="$1"
  local key="$2"
  local expected="$3"
  local actual="$4"

  if [[ "$actual" == "$expected" ]]; then
    printf '  [OK] %s %s = %s\n' "$profile" "$key" "$actual"
  else
    printf '  [CHECK] %s %s = %s, expected %s\n' "$profile" "$key" "${actual:-missing}" "$expected"
    failures=$((failures + 1))
  fi
}

pmset_output="$(pmset -g custom)"
printf '%s\n' "$pmset_output"

get_value() {
  local section="$1"
  local key="$2"
  awk -v section="$section" -v key="$key" '
    $0 == section ":" { in_section = 1; next }
    /^[[:alpha:]][[:alnum:] ]+:$/ { in_section = 0 }
    in_section && $1 == key { print $2; exit }
  ' <<<"$pmset_output"
}

cat <<'EOF'

Policy checks:
EOF

check_value "AC" "sleep" "0" "$(get_value "AC Power" sleep)"
check_value "AC" "displaysleep" "0" "$(get_value "AC Power" displaysleep)"
check_value "AC" "disksleep" "0" "$(get_value "AC Power" disksleep)"
check_value "Battery" "sleep" "15" "$(get_value "Battery Power" sleep)"
check_value "Battery" "displaysleep" "15" "$(get_value "Battery Power" displaysleep)"
check_value "Battery" "disksleep" "15" "$(get_value "Battery Power" disksleep)"

cat <<'EOF'

External-display note:
  macOS normally shows the login/unlock UI on the active/main display.
  Keeping AC sleep/display sleep disabled helps docked/clamshell wake behavior,
  but choosing which display is primary remains a macOS display arrangement setting.
EOF

if ((failures == 0)); then
  cat <<'EOF'

Result:
  power policy matches expected settings
EOF
  exit 0
fi

cat <<EOF

Result:
  power policy needs attention ($failures mismatch(es))
EOF
exit 1
