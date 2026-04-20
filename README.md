# Bluetooth Stability Helper

![Logo](assets/logo.svg)

Improve BLE/Bluetooth stability on rooted Android devices with a conservative Magisk module designed for safer tuning, easier recovery, and clearer user controls.

Created by **RogueAssassin**  
GitHub: https://github.com/RogueAssassin

![Magisk](https://img.shields.io/badge/Magisk-Compatible-brightgreen)
![Android](https://img.shields.io/badge/Android-13%2B-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Release](https://img.shields.io/badge/Release-v0.4.0-orange)

## Highlights

- Safer default install
- Pixel-first tuning, with Samsung/Xiaomi/generic profiles
- Preset modes through the Magisk action button
- Mode display before every change
- Import/export config bundles
- Logging and status snapshots
- Conservative watchdog and cooldown logic

## Modes

- **safe** — tweaks only, no watchdog
- **monitor** — health checks only, no recovery
- **recover** — health checks with guarded restart attempts
- **pixel_aggressive** — tighter intervals and optional idle tuning for Pixels

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

## Install

1. Download the latest release zip
2. Install it in Magisk
3. Reboot
4. Start in **safe**
5. Use the action button only after your first clean boot

## Files for GitHub releases

- Install zip: `releases/bt-stability-helper-v0.4.0.zip`
- Source package: attach the repo zip from this project directory

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
