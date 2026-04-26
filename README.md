# Bluetooth Stability Helper PRO v0.7.0

Magisk-side Bluetooth, BLE, location, Pokémon GO, Pokemod and vPGP3 stability helper.

## Why Magisk, not Vector/LSPosed?

This module fixes system-level Bluetooth/location behaviour. Vector/LSPosed hooks app/runtime behaviour. Keeping this as a Magisk module avoids touching ART hooks, Zygisk injection, or LSPosed/Vector internals.

Vector remains safe to run beside this module because this module does not force-stop Vector, change Zygisk, patch apps, or inject code.

## Modes

Create or edit:

```text
/sdcard/Download/Bluetooth-Stability-Helper/mode.txt
```

Supported modes:

- `safe` - light checks only
- `monitor` - diagnostics, no recovery toggles
- `standard` - recommended default
- `pokemon` - Pokémon GO/Pokemod/vPGP3 friendly defaults
- `aggressive` - stronger recovery for persistent dropouts
- `diagnostics` - slow loop with repeated status exports

You can also use Magisk Action to cycle modes.

## User config

Edit:

```text
/sdcard/Download/Bluetooth-Stability-Helper/user-config.sh
```

or import via:

```text
/sdcard/Download/Bluetooth-Stability-Helper/import/user-config.sh
```

Useful overrides:

```sh
MODE_DEFAULT="pokemon"
ENABLE_A2DP_OFFLOAD_DISABLE=1
POKEMOD_WARN_ONLY=1
ENABLE_BLUETOOTH_APP_FORCE_STOP=0
```

## Pokemod/vPGP3

Included Pokemod package candidate:

```text
com.pokemod.app.public
```

vPGP3 package names vary, so the module checks common candidates and exports what it finds in diagnostics.

## GitHub updates

Magisk update support is provided by `updateJson` in `module/module.prop` and root `update.json`.
