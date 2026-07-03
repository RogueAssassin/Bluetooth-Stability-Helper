# Bluetooth Stability Helper

<p align="center">
  <img src="assets/logo.png" alt="Bluetooth Stability Helper" width="420">
</p>

**Pixel-first Adaptive Bluetooth Stability Engine for Android**

Bluetooth Stability Helper is a Magisk module designed to improve Android Bluetooth, BLE, GATT, Companion Device, location, and idle-service stability. It is built mainly for Google Pixel devices while retaining safer support for other Android brands.

It is especially useful when Bluetooth-heavy apps are active, including **Pokémon GO**, **Pokemod from Pokemod.dev**, and **VPGP³+** style virtual accessory sessions.

## Key features

- Pixel-first Bluetooth stability tuning for Android 12–17.
- Adaptive Bluetooth health engine with BLE, GATT, HAL, binder, location, and idle-state checks.
- Pokémon GO and Pokemod awareness by package/name detection only.
- VPGP³+ stall detection for sessions that appear connected but stop progressing.
- Recovery history and health metrics stored under `/sdcard/Bluetooth-Stability-Helper/`.
- Vector/LSPosed safe: no app hooks, Zygisk hooks, or Xposed modules are installed.


## Logging safety

v1.0.2 switches to capped, event-based logging so the helper does not fill phone storage.

- Old logs and exports are cleaned on reboot.
- Routine keepalive/healthy-loop messages are suppressed by default.
- The active log rotates at 256 KB and keeps only a small number of rotated files.
- Exported diagnostics and Pixel snapshots are capped.
- Recovery history is trimmed automatically.

Useful overrides in `/sdcard/Bluetooth-Stability-Helper/user-config.sh`:

```sh
LOG_IMPORTANT_ONLY=1
LOG_BOOT_CLEAN=1
LOG_ROTATE_SIZE_KB=256
LOG_MAX_TOTAL_MB=10
EXPORT_MAX_FILES=8
RUN_DIAGNOSTICS_ON_BOOT=0
```

## Runtime files

```text
/sdcard/Bluetooth-Stability-Helper/
├── user-config.sh
├── status.txt
├── logs/
├── state/
├── metrics/
├── export/
└── import/
```

## Supported Android range

- Android 12 / 12L
- Android 13
- Android 14
- Android 15
- Android 16
- Android 17

Pixel devices receive the most specific tuning. Samsung, Xiaomi/Redmi/Poco, and generic Android devices use safer fallback profiles.

## Pokémon GO / Pokemod / VPGP³+ support

The module checks for names/packages such as:

- Pokémon GO: `com.nianticlabs.pokemongo`
- Pokemod: `com.pokemod.app.public` plus fallback Pokemod package names
- VPGP³+: Pokemod/VPGP³+ candidate labels

It does not track or enforce app versions. It does not automate gameplay. It focuses on Android Bluetooth/BLE/location stability and diagnostics while those apps are active.

## Optional user config

The module works out of the box. Optional overrides live here:

```text
/sdcard/Bluetooth-Stability-Helper/user-config.sh
```

Common safe overrides:

```sh
WATCHDOG_INTERVAL=40
STALE_SESSION_MINUTES=12
ENABLE_A2DP_OFFLOAD_DISABLE=1
MAX_RESTARTS_PER_HOUR=4
```

## Install

1. Install the module ZIP in Magisk.
2. Reboot.
3. Let the module run automatically.
4. Check status/logs under `/sdcard/Bluetooth-Stability-Helper/` if needed.

## Project assets

- `assets/logo.png` — current README logo.
- `assets/promo.png` — full promo graphic.
- `assets/banner.png` — wide banner graphic.
