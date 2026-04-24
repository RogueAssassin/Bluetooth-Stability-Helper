# Bluetooth Stability Helper

![Logo](assets/logo.svg)

Improve BLE/Bluetooth stability on rooted Android devices with a conservative Magisk module designed for safer tuning, clearer recovery modes, Pokemod-aware status checks, and easier GitHub release downloads.

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

- Safer default install
- Pixel-first tuning, with Samsung/Xiaomi/generic profiles
- Preset modes through the Magisk action button
- Mode display before every change
- Import/export config bundles
- Logging and status snapshots
- Conservative watchdog and cooldown logic
- Pokemod running/install checker, including `com.pokemod.app.public`
- GitHub updater manifest for Magisk-compatible managers
- GitHub release workflow that auto-attaches the install zip

## Modes

- **safe** — tweaks only, no watchdog
- **monitor** — health checks only, no recovery
- **recover** — health checks with guarded restart attempts
- **pixel_aggressive** — tighter intervals and optional idle tuning for Pixels

## Install

### Option 1 — GitHub Releases

1. Open the latest release page.
2. Download `bt-stability-helper-v0.6.0.zip` or the newest version shown there.
3. Install it in Magisk.
4. Reboot.

### Option 2 — Build locally from source

```bash
cd module
zip -r ../bt-stability-helper-v0.6.0.zip .
```

## Pokemod support checker

The checker looks for these packages by default:

```text
dev.pokemod com.pokemod com.pokemod.app com.pokemod.app.public com.pokemod.espresso com.roswell108.pokemodko
```

The current public Pokemod package name is included: `com.pokemod.app.public`.

## GitHub release setup

Push a tag like:

```bash
git tag v0.6.0
git push origin v0.6.0
```

The GitHub Actions workflow will package the module, create a GitHub Release, and attach the install zip.

See [STS_UPDATE_GUIDE.md](STS_UPDATE_GUIDE.md) for the full future update process.
