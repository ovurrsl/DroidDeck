# Galaxy Z Fold8: bring-up, measurements and work plan

Started 2026-10-14. This is a working document. The research below comes from a desk study; items
marked **to measure** have not been confirmed on a device yet and must not be treated as facts until
`tools/fold8/measure.sh` output backs them. Update this file as measurements land.

## Device

Galaxy Z Fold8 (SM-F971B / U / U1), 16 GB / 1 TB variant (the other storage models have 12 GB),
Android 17, One UI 9. Display, SoC and RAM figures match
[GSMArena](https://www.gsmarena.com/samsung_galaxy_z_fold_wide_5g-14673.php) (2026-10-14).

- Inner display 7.6", 2448x1848 (4:3, about 404 ppi). Cover display 5.5", 1248x1972 (428 ppi).
  120 Hz LTPO AMOLED. The panel's natural orientation is **to measure**.
- Snapdragon 8 Elite Gen 5 for Galaxy (SM8850-AC: 2 x 4.74 GHz + 6 x 3.63 GHz Oryon), Adreno 840v2,
  LPDDR5X, UFS 4.0. Graphite cooling, so long loads throttle hard (reports range from 43% to 71% of
  peak). **to measure** on this build.

## What already works

Upstream issue #65 reports the Fold8 (SM-F971B, Android 17, Adreno 840v2) running `main` with
Silksong at 104-114 fps. The work here is hardening, performance and a foldable-aware session, not
first bring-up.

The driver path is `tools/linuxfs/preload/kgslid.c` (device id 0x44050A21 to 0x44050A31) plus
DD-Turnip v0.2.0. Auto driver selection takes the newest DD-Turnip; there is no minimum version.

## Risks specific to Android 17 / One UI 9

| Topic | What we believe | Status |
|---|---|---|
| `targetSdkVersion 28` | Installs without a warning; app-data exec still allowed. Do not raise it: 29+ breaks PulseAudio and proot executing from app data. | to measure |
| Phantom process limit | Still 32. | to measure |
| Memory Limiter | New. If Samsung enables it: on the 16 GB tier a visible app gets about 10 GiB, a background one about 5 GiB plus 5 GiB swap, and an overrun is killed after about 30 s with `MemoryLimiter:AnonSwap`. The proot/Steam/Proton tree is probably counted as one app. | to measure (`am memory-limiter status`) |
| Background audio | Hardened, but the foreground service keeps it alive. | to measure |
| Auto Blocker | Blocks adb and sideloading. Must be off during development. | known |
| SSRM / GOS | Can clamp clocks to about 60% (issue #64). | to measure |
| DeX | "Resume" can hang (issue #586). | known, open |

## Page size

**Unknown.** No public source states the Fold8's kernel page size. What is known:

- Google documents 4 KB as the Android default and 16 KB as an option; the "Boot with 16KB page
  size" developer toggle is listed only for Pixel 8 and 9 models
  ([Google](https://developer.android.com/guide/practices/page-sizes)).
- Upstream issue #65 reports games running on the Fold8. That does not settle the page size: the
  claim that FEX and Wine ARM64EC cannot run on a 16 KB kernel comes from the original hand-off
  plan, is not in this repository's docs and is **unverified**.
- Android's 16 KB backcompat mode runs apps whose ELF files are 4 KB-aligned on a 16 KB kernel.
  That is what would happen to DroidDeck's six 4 KB-only PulseAudio libraries on such a device. It
  says nothing about which kernel the Fold8 has.

**To measure**: `adb shell getconf PAGE_SIZE`. A device with a 16 KB kernel also shows "Run app with
page size compat mode" under Settings > Apps > DroidDeck > Advanced; that row is absent on 4 KB
kernels. The emulator image `google_apis_ps16k` (already installed, used by AVD `Galaxy_Fold_8`)
can exercise the 16 KB path.

If a 16 KB build is ever required, several prebuilt libraries are not aligned for it:

- Six PulseAudio prebuilts in `app/src/main/jniLibs/arm64-v8a/` (`libpulse*.so`, `libltdl`,
  `libsndfile`) have LOAD segments aligned to 0x1000.
- The other native libraries end RELRO at a non-16 KB boundary because
  `-Wl,-z,common-page-size=16384` is missing in `app/src/main/cpp/CMakeLists.txt`.
- zstd-jni 1.5.2-3 (`app/build.gradle`) and NDK r27's `libc++_shared` are also unaligned.

The plan also states that FEX and Wine ARM64EC do not run on a 16 KB kernel at all. Treat that as
unverified until it is tested on a 16 KB image or device.

## Code issues found

Checked against `main` (07926175) on 2026-10-14: items 1 to 4 are confirmed in the code; item 5 was
not re-checked. `docs/progress-log.md` mentions `PerfHints.kt` and an ADPF hint session, but that
file is not on `main`; the log describes an unmerged branch.

1. `tools/linuxfs/overlay/usr/local/bin/droiddeck-session` `program_cores()` pins the desktop and
   run commands to two cores on a 2 + 6 layout, because it treats the two big cores as the
   "efficiency" set to exclude.
2. There is no ADPF or thermal-headroom code, and the release notes describing it are out of date.
   Do not bring back sustained performance mode: it lowers clocks.
3. The 4:3 inner display produces wrong geometry (issue #65 shows 952x720 stretched). Fold and unfold
   do not reapply `PerfMode` or the refresh rate, and `MainActivity` is recreated on every fold
   because `configChanges` is missing from the manifest.
4. Nothing reads `ApplicationExitInfo`, so a Memory Limiter kill is invisible, and `onTrimMemory`
   does not trigger zram handling.
5. GPU detection fallbacks do not know SM8850: `gpu/GpuInfo.kt` and `gpu/SocNames.kt` mishandle the
   `-AC` suffix, and `gpu_chipid` hex is read as "440".

## Development environment

Constraints that must not change: `targetSdkVersion 28`, AGP 8.8.0, Gradle 8.10.2, Kotlin 2.1.0.
Decline the Android Studio AGP 9.x upgrade suggestion.

### Windows (Android Studio)

- Gradle JDK: JDK 17 (Settings > Build, Execution, Deployment > Build Tools > Gradle). Gradle 8.10.2
  does not run on Java 25, which newer Studio builds bundle. Set `JAVA_HOME` to the same JDK 17.
- SDK: platform android-34 (required), android-37.0, NDK **27.3.13750724**, CMake **3.22.1**,
  Build-Tools 35.0.0 or newer, Platform-Tools 37 or newer.
- No Rust toolchain: add `-PskipRust=true` to Gradle command-line options.
- `git config --global core.autocrlf input` before cloning.
- Full APK packaging is not reliable on Windows (`verifyRuntimeInputs` compares paths and hashes
  recorded on Linux). Use Windows for code, `gradlew.bat -PskipRust=true :app:testDebugUnitTest`,
  Logcat, screen mirroring and the Layout Inspector. Build the APK in WSL2.

### WSL2 (full APK)

```
wsl --install -d Ubuntu-24.04            # %UserProfile%\.wslconfig: [wsl2] memory=12GB
sudo apt install openjdk-17-jdk python3 zstd unzip curl git build-essential
# rustup stable, then:
rustup target add aarch64-linux-android && cargo install cargo-ndk --locked
sdkmanager "platforms;android-34" "build-tools;35.0.0" "platform-tools" \
           "ndk;27.3.13750724" "cmake;3.22.1"
```

`~/.bashrc`: set `ANDROID_HOME`, `JAVA_HOME` and `DROIDDECK_NDK_VERSION=27.3.13750724`
(`tools/build_local.sh` defaults to macOS paths). Clone into the Linux filesystem, not `/mnt/c`.
Then `tools/build_local.sh` and `tools/deploy_local.sh`. Do not Clean or Rebuild from Studio. Use the
same platform-tools version in Windows and WSL.

### Emulator

Verified on 2026-10-14 (Android Studio AI-262, emulator 37.2.12, Windows 11):

```
avdmanager create avd -n Galaxy_Z_Fold8_API37 \
  -k "system-images;android-37.0;google_apis_playstore;x86_64" -d "7.6in Foldable"
```

Then edit only these keys in `~/.android/avd/Galaxy_Z_Fold8_API37.avd/config.ini`:

| Key | Value | Why |
|---|---|---|
| `PlayStore.enabled` | `yes` | Play image |
| `hw.cpu.ncore` | `8` | The guest reports 6 (`nproc`); the 2 + 6 layout is not reproducible |
| `hw.ramSize` | `16384` | 16 GB model |
| `hw.lcd.width` / `hw.lcd.height` | `1848` / `2448` | Inner display, portrait natural orientation |
| `hw.lcd.density` | `420` | Inner panel is about 404 ppi |
| `hw.displayRegion.0.1.width` / `.height` | `1248` / `1972` | Cover display |
| `hw.sensor.hinge.areas` | `924-0-1-2448` | Hinge at half width |
| `hw.gpu.enabled` | `yes` | |
| `disk.dataPartition.size` | `32G` | Runtime and games need room |

Checked in the guest: Android 17 (API 37), `getconf PAGE_SIZE` = 4096, `MemTotal` ~16 GB, density 420,
`cmd device_state print-states` lists CLOSED, HALF_OPENED and OPENED, and `adb emu posture 1|2|3`
moves between them.

Known limits of this emulator setup (measured, not assumed):

- **Samsung's Galaxy_Z_Fold8 skin breaks folding.** With `skin.path` set, the skin fixes the
  display at 2448x1848 and `adb emu fold` does nothing. The AVD runs without a skin.
- **The display does not shrink when closed.** Posture changes reach the apps, but `wm size` and
  screenshots stay 1848x2448, so the cover-screen transition itself is not exercised. Defining the
  cover as `hw.display1.*` did not create a second display either.
- **Stand-in for the cover screen:** `adb shell wm size 1248x1972` and `adb shell wm density 420`,
  undone with `adb shell wm size reset`. This tests cover geometry, not the real transition.
- Refresh rate stays at 60 Hz (the guest lists 60, 30 and 20), so 120 Hz behavior is device-only.

The emulator matches screen size, density, RAM, Android version, fold states and (assumed) page
size. It does **not** emulate One UI, Adreno 840 / Turnip or the ARM CPU. "Not an Adreno GPU
(ranchu)" is expected: cancel it and do not install the 791 MB driver. Game and Proton testing is
device-only.

### Phone

`tools/fold8/phone-setup.sh` lists and (with `--apply`) sets what adb can; the rest is menus.
`tools/fold8/measure.sh` records the numbers this document needs.

## Measurements to collect

Run `tools/fold8/measure.sh folded` and `tools/fold8/measure.sh unfolded`, and paste the results in
the table below.

| Item | Command | Result |
|---|---|---|
| Model | `getprop ro.product.model` | |
| Page size | `getconf PAGE_SIZE` | |
| RAM tier | `grep MemTotal /proc/meminfo` | |
| Memory limiter | `am memory-limiter status` | |
| Platform / SoC | `ro.board.platform`, `ro.soc.model`, `ro.vendor.qti.soc_name` | |
| GPU | `/sys/class/kgsl/kgsl-3d0/gpu_model` | |
| CPU max freqs | `cpuinfo_max_freq` per core | |
| Display size | `wm size` folded / unfolded | |
| Hinge feature | `pm list features \| grep hinge` | |
| Phantom monitor | `settings get global settings_enable_monitor_phantom_procs` | |

## Work plan

One branch and one pull request per item. Order: 1, measurements, then 2 to 9.

| # | Branch | Change |
|---|---|---|
| 1 | `claude/fold8-docs` | This document, `tools/fold8/`, README wording for the child-process option |
| 2 | `claude/fold8-cpu-pinning` | `program_cores` excludes only a real efficiency cluster; on 2 + 6 use all cores |
| 3 | `claude/fold8-gpu-detect` | SOC_MODEL `-AC` suffix, chipid hex parsing, one shared parser for `GpuInfo` and `TurnipDriver`, measured platform code, DD-Turnip minimum for Adreno 840 |
| 4 | `claude/fold8-android17-diag` | `ApplicationExitInfo` (MemoryLimiter) reader, page size and RAM tier in `DeviceReport`, warn when PAGE_SIZE is not 4096, `onTrimMemory` to zram |
| 5 | `claude/fold8-fold-display` | `configChanges` for the activities, reapply `PerfMode` and refresh on fold/unfold, 4:3 geometry, Follow screen bound |
| 6 | `claude/fold8-16kb-flags` | `common-page-size=16384` for native builds and an APK alignment gate |
| 7 | `claude/fold8-16kb-deps` | zstd-jni upgrade, static or newer libc++ |
| 8 | `claude/fold8-pulseaudio-16kb` | Rebuild PulseAudio 13, sndfile and ltdl with 16 KB alignment |
| 9 | `claude/fold8-thermal` | ADPF hint session and thermal headroom, no sustained mode |

After those: hinge-aware split controls (androidx.window) and the DeX "Resume" hang (#586).

Per-PR checks: `./gradlew -PskipRust=true :app:testDebugUnitTest :app:testReleaseUnitTest`,
`bash tools/test_local.sh` (WSL), and `llvm-readelf -lW` on native changes. After CI is green,
install the `droiddeck-apk` artifact on the Fold8 and check with `tools/droiddeckctl` and Logcat.
