#!/usr/bin/env bash
# Phone settings DroidDeck needs on a Galaxy Z Fold8 (docs/development/galaxy-z-fold8.md).
#
# Dry run by default: prints what it would change and the steps that can only
# be done by hand in the phone's menus. Pass --apply to write the settings
# that adb is allowed to change.
#
# Usage: tools/fold8/phone-setup.sh [--apply]
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
adb_bin=${ADB:-adb}
apply=0
case "${1:-}" in
    "") ;;
    --apply) apply=1 ;;
    -h | --help)
        sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "unknown argument: $1" >&2
        exit 2
        ;;
esac

serial=$(python3 "$repo_root/tools/adb_device.py" --adb "$adb_bin")
adb_cmd=("$adb_bin" -s "$serial")

current=$("${adb_cmd[@]}" shell settings get global settings_enable_monitor_phantom_procs | tr -d '\r')
echo "phantom process monitor setting: ${current:-unset} (want: false)"

if [[ $current == false ]]; then
    echo "  already false, nothing to change"
elif ((apply)); then
    "${adb_cmd[@]}" shell settings put global settings_enable_monitor_phantom_procs false
    echo "  set to false"
else
    echo "  would run: adb shell settings put global settings_enable_monitor_phantom_procs false"
fi

cat <<'EOF'

Steps only the phone's menus can do (adb cannot change these):
  1. Settings > Developer options: keep ON, and turn ON
     "Disable child process restrictions" (shown as "Restrict child processes"
     on some builds; the goal is that child processes are NOT restricted).
  2. Developer options: USB debugging ON, Wireless debugging ON.
  3. Settings > Security and privacy > Auto Blocker: OFF (it blocks adb and sideloading).
  4. Settings > Apps > DroidDeck > Battery: Unrestricted.
  5. Settings > Battery > Background usage limits: add DroidDeck to
     "Never sleeping apps", and turn OFF "Put unused apps to sleep".
  6. Game Launcher / Gaming Hub: add DroidDeck (Performance).
  7. Settings > Display > Motion smoothness: Adaptive or High (120 Hz).
  8. Settings > Display > App screen ratio: DroidDeck = "App default".
EOF
