# Bluetooth Stability Helper

![Logo](assets/logo.svg)

Improve BLE/Bluetooth stability on rooted Android devices with a conservative Magisk module designed for safer tuning, clearer recovery modes, and easier release downloads.

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

## Highlights

- Safer default install
- Pixel-first tuning, with Samsung/Xiaomi/generic profiles
- Preset modes through the Magisk action button
- Mode display before every change
- Import/export config bundles
- Logging and status snapshots
- Conservative watchdog and cooldown logic
- GitHub release workflow that auto-attaches the install zip

## Modes

- **safe** — tweaks only, no watchdog
- **monitor** — health checks only, no recovery
- **recover** — health checks with guarded restart attempts
- **pixel_aggressive** — tighter intervals and optional idle tuning for Pixels

## Install

### Option 1 — GitHub Releases
1. Open the latest release page
2. Download `bt-stability-helper-v0.5.0.zip` or the newest version shown there
3. Install it in Magisk
4. Reboot

### Option 2 — Build locally from source
1. Enter the `module/` folder
2. Zip the contents of the folder, not the folder itself
3. Install the resulting zip in Magisk

## Magisk action button behavior

Tap the action button in Magisk to:

1. Show the current mode
2. Import settings if an import bundle is present
3. Otherwise cycle to the next mode
4. Export the current bundle and a status snapshot

### Mode order

`safe -> monitor -> recover -> pixel_aggressive -> safe`

## Import / export

### Export
Every action-button run writes a fresh bundle to:

`/sdcard/Download/Bluetooth-Stability-Helper/export/`

Files:
- `user-mode.txt`
- `user-config.sh`
- `status.txt`
- `log-tail.txt`

### Import
Place one or both of these into:

`/sdcard/Download/Bluetooth-Stability-Helper/import/`

Files:
- `user-mode.txt`
- `user-config.sh`

Then tap the Magisk action button. The module will import them and keep the imported mode/config.

## GitHub release setup

This repo is preconfigured so releases are easier for users to find and download.

### What happens when you publish a tag
Push a tag like:

```bash
git tag v0.5.0
git push origin v0.5.0
```

The GitHub Actions workflow will:
1. package the module
2. create a GitHub Release
3. attach the install zip as a release asset

That means users can just click **Releases** and download the zip directly.

### Recommended repo settings
- Repository name: `Bluetooth-Stability-Helper`
- Keep **Issues** enabled
- Keep **Releases** enabled
- Optional: pin the latest release in your GitHub repo description

## Notes

- This project is intentionally conservative by default
- It does not guarantee compatibility with every vendor Bluetooth stack
- `pixel_aggressive` should be treated as an advanced mode
- Use logs before assuming the accessory or app is the problem

## Testing checklist

- Confirm boot completes normally
- Check the current mode in Magisk action output
- Review `/data/adb/modules/btstabilityhelper/bt-stability.log`
- Review exported `status.txt`
- Move to a stronger mode only if needed

## Planned next steps

- Better Bluetooth-manager state parsing
- Optional vendor presets in imported bundles
- Clearer recovery reason logging
- More polished screenshots and branding
