# Changelog

## v1.0.4 - Magisk updater metadata fix

- Bumped module to v1.0.4 / versionCode 1004.
- Fixed update manifest versionCode consistency so Magisk can detect updates correctly.
- Added workflow validation for module.prop, update.json, release tag, and release ZIP naming.
- No runtime Bluetooth or log-system changes.

## v1.0.3

- Added Pixel Android 17 July 2026 CP2A.260705 build-family awareness.
- Recognises CP2A.260705.006 / CP2A.260705.006.A1 as current Android 17 July Pixel firmware.
- Leaves the v1.0.2 capped/event-based log system unchanged.
- No aggressive Bluetooth behaviour changes required for this patch.

## v1.0.2

- Fixed runaway logging that could grow into multi-GB storage usage.
- Added boot cleanup for old logs and diagnostics exports.
- Added event-based logging so normal healthy watchdog loops stay quiet.
- Added aggressive log rotation and total log-folder storage cap.
- Capped diagnostics exports, Pixel connectivity snapshots, and recovery history.
- Disabled boot diagnostics export by default; diagnostics still export on important stalls/recoveries.
- Kept Pixel-first Android 12–17 Bluetooth stability engine, Pokémon GO, Pokemod, and VPGP³+ support.

## v1.0.1

- Promoted the project to the standard adaptive Bluetooth stability engine.
- Added Bluetooth health scoring and metrics export.
- Added monthly Pixel firmware/build/security-patch awareness without hard-coding unreleased updates.
- Kept Android 12-17 support with Pixel-first tuning.
- Kept Pokémon GO, Pokemod, and VPGP³+ support name/package based only, with no app-version lock-in.
- Added recovery history JSONL metrics.
- Retained GitHub updater, workflows, repo layout, logo, and `/sdcard/Bluetooth-Stability-Helper/` runtime paths.

## v0.10.0

- Added Android 17 / SDK 37 support range while retaining Android 12-16 behaviour.
- Added Pixel Android 17 adaptive guard for current Google firmware families.
- Added Android 17 Companion Device Manager, Nearby/Bluetooth permission, BLE privacy/RPA, background-audio, and memory-pressure observers.
- Tightened Pixel Android 17 VPGP³+ stale-session timing and keepalive intervals.
- Diagnostics now export Android 16/17 companion, role, permission, Bluetooth, location, and VPGP³+ signals.
- Repo style, GitHub updater, workflows, logo, and `/sdcard/Bluetooth-Stability-Helper/` runtime path retained.

## v0.9.2
- Adds Pixel Android 16 May 2026 CP1A.260505.005 build guard.
- Adds Android 16 companion-device, bond-loss, and encryption-change observers.
- Adds Pixel connectivity snapshots on stalls.
- Tightens Pixel CP1A stale-session recovery defaults while retaining Android 12-15 compatibility.

- Adds Interaction Freeze Guard for the exact symptom where Pokémon GO reaches a stop/Pokémon and the VPGP³+ interaction freezes while Bluetooth still appears connected.
- Tightens Pixel-first watchdog interval and recovery cooldown.
- Adds GMS/location keepalive polling while Pokémon GO/Pokemod/VPGP³+ style Bluetooth sessions are active.
- Improves Android 12-16 app idle, background, wakelock, Bluetooth scan/connect, and location appops handling.
- Keeps GitHub updater, repo layout, logo, and /sdcard/Bluetooth-Stability-Helper runtime path.

## v0.9.0
- Adaptive Bluetooth Stability Engine focused on Pixel, Android 12-16, Pokémon GO, Pokemod and VPGP³+.
