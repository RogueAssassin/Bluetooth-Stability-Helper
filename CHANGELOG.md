# Changelog

## v0.8.0

- Moved runtime config, mode, logs, exports, and state to `/sdcard/Bluetooth-Stability-Helper/` so `/sdcard/Download` stays clean.
- Added Android 12-16 target range handling: SDK 31-36 checks and warnings.
- Added Pixel/Google profile with Android 16 guard tuning and A2DP offload disable option.
- Added Samsung and MIUI/Xiaomi/Redmi/Poco profile detection.
- Added `pixel` mode between `pokemon` and `aggressive`.
- Expanded diagnostics for Bluetooth/location settings, Bluetooth properties, appops, Pokémon GO, Pokemod, and vPGP3.
- Added safer restricted-standby/appops checks for Pokémon GO, Pokemod, vPGP3, Bluetooth, and Play Services.
- Kept GitHub Releases/Magisk update flow and existing logo path intact.

## v0.7.0

- PRO watchdog and guarded recovery ladder.
- Pokémon GO, Pokemod, and vPGP3-aware checks.
- Local mode/config support.
- GitHub Actions release flow.
