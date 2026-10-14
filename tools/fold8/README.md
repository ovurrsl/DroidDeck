# tools/fold8

Helpers for bringing DroidDeck up on a Galaxy Z Fold8 and measuring it. Background and
the work plan are in [docs/development/galaxy-z-fold8.md](../../docs/development/galaxy-z-fold8.md).

| Script | What it does | Changes the phone? |
|---|---|---|
| `measure.sh [label] [out]` | Collects the device facts the plan depends on (page size, memory tier, GPU, CPU clusters, display, fold features) into one text file. Run it folded and unfolded. | No |
| `phone-setup.sh [--apply]` | Shows, and with `--apply` writes, the adb-settable phone settings, and lists the menu steps adb cannot do. | Only with `--apply` |

Both pick the device through `tools/adb_device.py`, so `ADB_SERIAL` / `ANDROID_SERIAL` work when more
than one device is attached, and `ADB` overrides the adb binary.

On Windows run them from Git Bash or WSL; they need `bash` and `python3`.
