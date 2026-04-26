# Bluetooth Stability Helper PRO

![Logo](assets/logo.svg)

Improve BLE/Bluetooth stability on rooted Android devices with a conservative Magisk module designed for Android 12-16, Pixel/Google devices, Pokémon GO, Pokemod, vPGP3, location/BLE checks, diagnostics, and safer recovery modes.

Created by **RogueAssassin**  
GitHub: https://github.com/RogueAssassin

[![Magisk](https://img.shields.io/badge/Magisk-Compatible-brightgreen)](#install)
[![Android](https://img.shields.io/badge/Android-12--16-blue)](#install)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/RogueAssassin/Bluetooth-Stability-Helper?display_name=tag)](https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/RogueAssassin/Bluetooth-Stability-Helper/total)](https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases)

## Quick links

- **Latest release page:** https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases/latest
- **All releases:** https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases
- **Issues:** https://github.com/RogueAssassin/Bluetooth-Stability-Helper/issues
- **Update guide:** [STS_UPDATE_GUIDE.md](STS_UPDATE_GUIDE.md)

## Highlights

- Android 12-16 support range with SDK-aware checks
- Pixel/Google profile with Android 16 guard tuning
- Samsung and MIUI/Xiaomi/Redmi/Poco profile detection
- PRO Bluetooth watchdog and guarded recovery ladder
- Local mode control through `/sdcard/Bluetooth-Stability-Helper/mode.txt`
- Logs, state, exports, and config saved under `/sdcard/Bluetooth-Stability-Helper/`
- Pokémon GO, Pokemod, and vPGP3-aware checks
- Pokemod package support including `com.pokemod.app.public`
- Location/BLE/Bluetooth diagnostics
- Safe Vector/LSPosed coexistence: no Zygisk/ART hooks are changed
- GitHub updater manifest for Magisk-compatible managers
- GitHub release workflow that auto-attaches the install zip

## Modes

- **safe** — light checks only
- **monitor** — diagnostics only, no recovery toggles
- **standard** — balanced default
- **pokemon** — Pokémon GO/Pokemod/vPGP3 friendly defaults
- **pixel** — Pixel/Google focused Bluetooth stability profile
- **aggressive** — stronger guarded recovery for persistent dropouts
- **diagnostics** — slow loop with repeated status exports

## Install

### Option 1 — GitHub Releases

1. Open the latest release page.
2. Download `bt-stability-helper-v0.8.0.zip` or the newest version shown there.
3. Install it in Magisk.
4. Reboot.

### Option 2 — Build locally from source

```bash
cd module
zip -r ../bt-stability-helper-v0.8.0.zip .
```

## Local mode file

Create or edit:

```text
/sdcard/Bluetooth-Stability-Helper/mode.txt
```

Recommended first value:

```text
pokemon
```

For Pixel devices on Android 16, try:

```text
pixel
```

## Logs and diagnostics

Runtime files are saved to:

```text
/sdcard/Bluetooth-Stability-Helper/
```

Important files:

```text
/sdcard/Bluetooth-Stability-Helper/mode.txt
/sdcard/Bluetooth-Stability-Helper/user-config.sh
/sdcard/Bluetooth-Stability-Helper/status.txt
/sdcard/Bluetooth-Stability-Helper/export/status.txt
/sdcard/Bluetooth-Stability-Helper/logs/bt-stability.log
```

## GitHub Desktop release setup

This repo is designed to be updated through GitHub Desktop plus GitHub Releases. You do not need Git Bash for the normal flow.

1. Open this repo in GitHub Desktop.
2. Make your file changes.
3. Commit to `main` with a message like `Release v0.8.0`.
4. Click **Push origin**.
5. In GitHub Desktop, create a tag named `v0.8.0` on the release commit and push the tag.
6. GitHub Actions will build `bt-stability-helper-v0.8.0.zip` and attach it to the release.
7. Confirm `update.json` points to the same release ZIP.

See [STS_UPDATE_GUIDE.md](STS_UPDATE_GUIDE.md) for the full future update process.
