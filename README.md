<div align="center">

<img src="assets/BSH-Bluetooth-Stability-Helper-Banner.png" width="920" alt="Bluetooth Stability Helper — Rogue ecosystem banner">

# Bluetooth Stability Helper

**Pixel-first adaptive Bluetooth stability engine for Android**

[![Channel](https://img.shields.io/badge/CHANNEL-STABLE-8b5cf6?style=for-the-badge&labelColor=45464d)](https://github.com/RogueAssassin/Bluetooth-Stability-Helper/tree/main)
[![Build](https://img.shields.io/github/actions/workflow/status/RogueAssassin/Bluetooth-Stability-Helper/package.yml?branch=main&style=for-the-badge&label=BUILD&labelColor=45464d)](https://github.com/RogueAssassin/Bluetooth-Stability-Helper/actions/workflows/package.yml?query=branch%3Amain)
![Android](https://img.shields.io/badge/ANDROID-12--17-00cbe6?style=for-the-badge&labelColor=45464d)
![Profile](https://img.shields.io/badge/PROFILE-PIXEL%20FIRST-42d6a4?style=for-the-badge&labelColor=45464d)

</div>

Bluetooth Stability Helper is a Magisk module designed to improve Android Bluetooth, BLE, GATT, Companion Device, location and idle-service stability. Google Pixel is the primary tuning target, with conservative profiles for other supported Android manufacturers.

It is particularly useful for long-running Bluetooth-heavy sessions such as **Pokémon GO**, **Pokemod** and **VPGP³+** style virtual accessory use. The module does not automate gameplay and does not require Zygisk, Xposed or application hooks.

## Highlights

- evidence-based Bluetooth health and recovery engine
- fresh-fault detection for GATT, HAL, binder and adapter failures
- explicit recovery-state tracking with cooldowns and hourly recovery limits
- conservative OEM-specific profiles with a safe generic fallback
- Android 16/17 Companion Device and bond-change awareness
- persistent bounded health, event and recovery telemetry
- watchdog heartbeat and post-recovery verification
- restricted, validated user configuration
- reversible optional tuning with uninstall restoration
- capped event-based logging and diagnostics
- modern Magisk installer and non-destructive verification tooling
- boot-ready schema-v3 manager API for the companion app
- native Android companion app for health, event timeline, full device/engine context and sanitized diagnostic reports
- companion APK is built into the module package and installed/updated during module installation when available

## How it works

The module waits for Android to finish booting, detects the device/profile, applies conservative static policy, then runs a lightweight watchdog. Recovery is only considered after fresh concrete fault evidence is observed and confirmed.

```text
HEALTHY → SUSPECT → DEGRADED → RECOVERY_PENDING → RECOVERING → COOLDOWN
```

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for the complete boot, monitoring, recovery, telemetry and manager API data flow.

## Supported Android range

- Android 12 / 12L
- Android 13
- Android 14
- Android 15
- Android 16
- Android 17

| Device family | Runtime profile | Default recovery policy |
| --- | --- | --- |
| Google Pixel | Primary Pixel | 2 faults in 3 minutes; maximum 2 recoveries/hour |
| Samsung / One UI | Conservative Samsung | 3 faults in 4 minutes; maximum 1 recovery/hour |
| Xiaomi / Redmi / Poco | Conservative Xiaomi | 3 faults in 4 minutes; maximum 1 recovery/hour |
| OnePlus / Oppo / Realme | Conservative OPlus | 3 faults in 4 minutes; maximum 1 recovery/hour |
| Nothing, Motorola, ASUS/ROG, Sony, Vivo/iQOO | Conservative OEM | 3 faults in 4 minutes; maximum 1 recovery/hour |
| Huawei / Honor | Diagnostic fallback | Automatic adapter recovery disabled |
| Unknown OEM on Android 12–17 | Generic safe fallback | 3 faults in 4 minutes; maximum 1 recovery/hour |
| Android outside the validated range | Unsupported fallback | Diagnostics only; automatic recovery disabled |

## Pokémon GO / Pokemod / VPGP³+

Detection is package/name based only.

- Pokémon GO: `com.nianticlabs.pokemongo`
- Pokemod: `com.pokemod.app.public`
- VPGP³+: candidate labels/packages when present

The module watches Android Bluetooth, BLE, GATT, location and companion-device behaviour while supported apps are active. App names or elapsed session time alone are never treated as Bluetooth failure evidence.

## Install

1. Install the module ZIP using Magisk.
2. Review the detected device, Android build, Bluetooth stack and selected profile shown by the installer.
3. The bundled BSH Companion APK is installed or updated automatically when package installation is available.
4. Reboot.
5. Open **BSH Companion** for health/timeline/support views, or use the Magisk Action for diagnostics.

The installer distinguishes clean installs from upgrades, validates required files and shell syntax, preserves restoration data and does not overwrite the external user configuration. A companion-app install failure does not abort the root module installation.

## Configuration

Optional overrides live at:

```text
/sdcard/Bluetooth-Stability-Helper/user-config.sh
```

Common safe overrides:

```sh
WATCHDOG_INTERVAL=40
STALE_SESSION_MINUTES=20
ENABLE_A2DP_OFFLOAD_DISABLE=0
MAX_RESTARTS_PER_HOUR=2
RECOVERY_COOLDOWN=600
```

Shared-storage configuration is parsed as a restricted set of validated scalar values. It is never executed as unrestricted root shell code.

## Runtime data

```text
/sdcard/Bluetooth-Stability-Helper/
├── user-config.sh
├── install-report.txt
├── status.txt
├── logs/
├── state/
├── metrics/
├── export/
├── api/
└── import/
```

Logging and telemetry are bounded so the module does not grow indefinitely. Routine healthy-loop messages are suppressed, active logs rotate, exports are capped and persistent event/recovery history is trimmed automatically.

## Recovery policy

Bluetooth is not refreshed because an app has been running for a long time. Recovery requires fresh concrete failure evidence such as repeated GATT errors, binder/process death or a confirmed Bluetooth manager failure.

Pixel uses the quickest validated confirmation policy. Other OEM profiles use slower thresholds, and Huawei/Honor plus unsupported Android versions default to diagnostics-only behaviour. Android 17 bond/Companion Device observations remain diagnostic so platform autonomous re-pairing is not interrupted.

## Diagnostics

The Magisk Action, companion app and `verify.sh` expose:

- selected OEM profile and Android/build information
- Bluetooth adapter and process health
- watchdog heartbeat state
- health score and recovery state
- normalized fault/recovery telemetry
- recent Bluetooth/location logs
- Companion Device and permission state
- bounded diagnostics exports

## v1.7 runtime reliability

The watchdog now includes a low-overhead periodic runtime self-check for writable BSH state/metrics storage and the abnormal case where Bluetooth is enabled but no known Bluetooth process exists. It reports repeated degradation through bounded telemetry without bypassing the existing evidence threshold, cooldown or recovery caps.

## Companion app

The native Android companion app lives in `companion-app/`. It does not replace the Magisk module or implement recovery itself.

The app provides live module health and recovery state, OEM/device/build/root context, effective watchdog/recovery settings, API lifecycle/freshness, a normalized event timeline and locally generated sanitized diagnostic support reports. It exposes no arbitrary shell console or generic root command channel.

The app uses the schema-versioned read-only manager contract and reads only fixed BSH runtime paths through root. Official v1.7+ APKs use one persistent signing identity across testing and stable releases, enforced by CI certificate verification. The canonical manager snapshot lives inside the Magisk module tree, with a best-effort shared-storage mirror for diagnostics. The module continues to operate normally if the app is not installed.

## Security and compatibility

Bluetooth Stability Helper does **not** include Play Integrity spoofing, keybox management, Zygisk injection, app hiding, device fingerprint modification, ART hooks or Xposed modules.

Unknown devices receive conservative fallback behaviour rather than guessed vendor tweaks. Optional global changes are backed up and restored on uninstall.

## Branding

The supplied full-quality PNG artwork is canonical:

- `assets/BSH-Bluetooth-Stability-Helper-Banner.png` — README/project banner
- `assets/BSH-Bluetooth-Stability-Helper-Logo.png` — primary project and app identity

## Documentation

- **[Architecture](ARCHITECTURE.md)** — module lifecycle and data flow
- **[Manager API](docs/MANAGER_API.md)** — companion-app contract and security boundary
- **[Companion signing](docs/SIGNING.md)** — permanent signing identity and update guarantees
- **[Companion app](companion-app/README.md)** — Android app structure, build and data access
- **[Changelog](CHANGELOG.md)** — complete release history and current development changes
- **[Contributing](CONTRIBUTING.md)** — contribution notes

## Project references

The installation and lifecycle design was reviewed against the official Magisk module developer guide, MMT-Extended, Advanced Charging Controller and Vector's bundled-manager packaging pattern. These are design references only; Bluetooth Stability Helper retains its own recovery architecture and does not adopt Vector's Zygisk/Xposed hooking model.
