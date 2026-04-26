# Bluetooth Stability Helper PRO

![Logo](assets/logo.svg)

Improve BLE/Bluetooth stability on rooted Android devices with a conservative Magisk module designed for Pokémon GO, Pokemod, vPGP3, location/BLE checks, diagnostics, and safer recovery modes.

Created by **RogueAssassin**  
GitHub: https://github.com/RogueAssassin

[![Magisk](https://img.shields.io/badge/Magisk-Compatible-brightgreen)](#install)
[![Android](https://img.shields.io/badge/Android-13%2B-blue)](#install)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/RogueAssassin/Bluetooth-Stability-Helper?display_name=tag)](https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/RogueAssassin/Bluetooth-Stability-Helper/total)](https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases)

## Quick links

- **Latest release page:** https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases/latest
- **All releases:** https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases
- **Issues:** https://github.com/RogueAssassin/Bluetooth-Stability-Helper/issues
- **Update guide:** [STS_UPDATE_GUIDE.md](STS_UPDATE_GUIDE.md)

## Highlights

- PRO Bluetooth watchdog and guarded recovery ladder
- Local mode control through `/sdcard/Download/Bluetooth-Stability-Helper/mode.txt`
- Pokémon GO, Pokemod, and vPGP3-aware checks
- Pokemod package support including `com.pokemod.app.public`
- Location/BLE/Bluetooth diagnostics
- Safe Vector/LSPosed coexistence: no Zygisk/ART hooks are changed
- GitHub updater manifest for Magisk-compatible managers
- GitHub release workflow that auto-attaches the install zip

## Modes

- **safe** — light checks only
- **monitor** — diagnostics only, no recovery toggles
- **standard** — recommended default
- **pokemon** — Pokémon GO/Pokemod/vPGP3 friendly defaults
- **aggressive** — stronger guarded recovery for persistent dropouts
- **diagnostics** — slow loop with repeated status exports

## Install

### Option 1 — GitHub Releases

1. Open the latest release page.
2. Download `bt-stability-helper-v0.7.0.zip` or the newest version shown there.
3. Install it in Magisk.
4. Reboot.

### Option 2 — Build locally from source

```bash
cd module
zip -r ../bt-stability-helper-v0.7.0.zip .
```

## Local mode file

Create or edit:

```text
/sdcard/Download/Bluetooth-Stability-Helper/mode.txt
```

Recommended first value:

```text
pokemon
```

## GitHub release setup

Push a tag like:

```bash
git tag v0.7.0
git push origin v0.7.0
```

The GitHub Actions workflow will package the module, create a GitHub Release, and attach the install zip.

See [STS_UPDATE_GUIDE.md](STS_UPDATE_GUIDE.md) for the full future update process.
