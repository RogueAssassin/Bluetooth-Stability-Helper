# Bluetooth Stability Helper

![Bluetooth Stability Helper logo](assets/logo.svg)

**v1.0.0 Adaptive Bluetooth Stability Engine**

A Magisk module focused on reducing Bluetooth and BLE dropouts on Android 12-17, with Pixel-first tuning and extra context awareness for **Pokémon GO**, **Pokemod from Pokemod.dev**, and **VPGP³+** style Bluetooth accessory sessions.

## v1.0.0 focus

- One standard adaptive Bluetooth engine; no mode switching.
- Pixel-first Android 12-17 Bluetooth, BLE, GATT, Companion Device, location, idle, and firmware/build-family awareness.
- Monthly Pixel patch readiness by SDK, build ID, build family, and security patch level.
- Pokémon GO and Pokemod support by package/name detection only. No app-version lock-in.
- VPGP³+ stall handling for sessions that start catching/spinning and then freeze while Bluetooth still appears connected.
- Bluetooth health scoring exported to `/sdcard/Bluetooth-Stability-Helper/metrics/bluetooth-health.json`.
- Recovery history exported to `/sdcard/Bluetooth-Stability-Helper/metrics/recovery-history.jsonl`.
- Diagnostics exports under `/sdcard/Bluetooth-Stability-Helper/export/`.
- GitHub/Magisk update JSON retained.
- Vector/LSPosed safe: this module does not install app hooks, Zygisk hooks, or Xposed modules.

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

Pixel devices receive the most specific tuning. Samsung, Xiaomi/Redmi/Poco, and generic Android devices remain supported with safer generic profiles.

## Pokémon GO / Pokemod / VPGP³+ support

The module checks for names/packages such as:

- Pokémon GO: `com.nianticlabs.pokemongo`
- Pokemod: `com.pokemod.app.public` plus fallback Pokemod package names
- VPGP³+: Pokemod/VPGP³+ candidate names only

It does **not** track or enforce app versions. It does **not** automate gameplay. It focuses on Android Bluetooth/BLE/location stability and diagnostics while those apps are active.

## User config

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

## GitHub updater

`module.prop` points to:

```text
https://raw.githubusercontent.com/RogueAssassin/Bluetooth-Stability-Helper/main/update.json
```

For future updates, use GitHub Desktop for normal commits/pushes, then create the matching GitHub Release and upload the Magisk ZIP asset. Keep `version`, `versionCode`, release tag, ZIP filename, and `update.json` aligned.
