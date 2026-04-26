# Changelog

## v0.7.0

- Promoted module to Bluetooth Stability Helper PRO.
- Added config-file mode control via `/sdcard/Download/Bluetooth-Stability-Helper/mode.txt`.
- Added Pokémon mode for Pokémon GO + Pokemod + vPGP3 coexistence.
- Added checks for Bluetooth processes, Bluetooth manager state, location mode, BLE scan settings, app ops and battery/idle whitelisting.
- Added safer recovery ladder: audio route repair first, adapter toggle second, optional Bluetooth app force-stop only in aggressive mode/config.
- Added diagnostics exporter with Bluetooth, location, process and package state.
- Preserved GitHub update JSON support.
- Kept Vector/LSPosed untouched for compatibility.

## v0.6.0

- Added GitHub updater files and Pokemod package detection for `com.pokemod.app.public`.
