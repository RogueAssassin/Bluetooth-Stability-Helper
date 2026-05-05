# Changelog

## v0.9.1
- Adds Interaction Freeze Guard for the exact symptom where Pokémon GO reaches a stop/Pokémon and the VPGP³+ interaction freezes while Bluetooth still appears connected.
- Tightens Pixel-first watchdog interval and recovery cooldown.
- Adds GMS/location keepalive polling while Pokémon GO/Pokemod/VPGP³+ style Bluetooth sessions are active.
- Improves Android 12-16 app idle, background, wakelock, Bluetooth scan/connect, and location appops handling.
- Keeps GitHub updater, repo layout, logo, and /sdcard/Bluetooth-Stability-Helper runtime path.

## v0.9.0

- Introduced the Adaptive Bluetooth Stability Engine.
- Removed dependency on multiple user-facing modes; standard behaviour now focuses on Bluetooth stability automatically.
- Added Pixel-first Android 12-16 Bluetooth/BLE tuning, with Android 16 guards.
- Improved VPGP³+ stale-session handling for Pokémon GO + Pokemod sessions.
- Added Bluetooth-aware game/app detection.
- Added safer BLE keepalive polling and better GATT/log stall detection.
- Kept all logs/config under `/sdcard/Bluetooth-Stability-Helper/`.
- Retained GitHub update JSON and release workflow.
- Kept Vector/LSPosed untouched.

## v0.8.1

- Added Pokémon Plus/VPG session stale-session monitoring.
- Improved diagnostics for BLE/GATT/location stalls.

## v0.8.0

- Moved runtime files out of Downloads.
- Added Pixel and Android 12-16 support checks.
