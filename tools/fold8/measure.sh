#!/usr/bin/env bash
# Read-only device measurements for the Galaxy Z Fold8 investigation
# (docs/development/galaxy-z-fold8.md). Changes nothing on the phone.
#
# Usage: tools/fold8/measure.sh [label] [output-file]
#   label        free text stored in the header, e.g. "folded" or "unfolded"
#   output-file  defaults to fold8-measurements-<label>-<UTC timestamp>.txt
#
# Run it twice, once folded and once unfolded: `wm size` and the display
# sections differ between the two postures.
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
adb_bin=${ADB:-adb}
label=${1:-unlabeled}
stamp=$(date -u +%Y%m%dT%H%M%SZ)
out=${2:-"fold8-measurements-${label}-${stamp}.txt"}

serial=$(python3 "$repo_root/tools/adb_device.py" --adb "$adb_bin")
adb_cmd=("$adb_bin" -s "$serial")

# Run one device command; never abort the sweep when a command is missing on
# this build (am memory-limiter, for one, only exists on newer One UI).
probe() {
    local title=$1
    shift
    {
        printf '\n### %s\n$ adb shell %s\n' "$title" "$*"
        "${adb_cmd[@]}" shell "$@" 2>&1 || printf '(exit status %s)\n' "$?"
    } >>"$out"
}

{
    printf 'DroidDeck Fold8 measurements\n'
    printf 'label: %s\n' "$label"
    printf 'utc:   %s\n' "$stamp"
    printf 'serial: %s\n' "$serial"
} >"$out"

probe "model" getprop ro.product.model
probe "android release / sdk" 'getprop ro.build.version.release; getprop ro.build.version.sdk'
probe "one ui build" getprop ro.build.version.oneui
probe "page size (expect 4096; 16384 breaks FEX and Wine ARM64EC)" getconf PAGE_SIZE
probe "MemTotal" 'grep MemTotal /proc/meminfo'
probe "memory limiter status" am memory-limiter status
probe "board platform" getprop ro.board.platform
probe "soc model" getprop ro.soc.model
probe "qti soc name" getprop ro.vendor.qti.soc_name
probe "kgsl gpu model" cat /sys/class/kgsl/kgsl-3d0/gpu_model
probe "kgsl gpu chipid" cat /sys/class/kgsl/kgsl-3d0/gpu_id
probe "cpu max freqs (kHz)" 'cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq'
probe "wm size" wm size
probe "wm density" wm density
probe "hinge / fold features" 'pm list features | grep -i -E "hinge|fold"'
probe "phantom process monitor setting" settings get global settings_enable_monitor_phantom_procs
probe "developer options enabled" settings get global development_settings_enabled
probe "adb enabled" settings get global adb_enabled
probe "display refresh / modes" 'dumpsys display | grep -i -E "mode|refresh|DisplayDeviceInfo" | head -40'

printf 'wrote %s\n' "$out" >&2
