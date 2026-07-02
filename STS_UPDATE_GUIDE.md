# STS Update Guide - GitHub Desktop Flow

This project uses the same repo-style flow: source files in the repo root, installable Magisk files in `module/`, workflows in `.github/workflows/`, and Magisk updater metadata in `update.json`.

## Future update steps

1. Open the repo in GitHub Desktop.
2. Pull the latest `main`.
3. Edit the module files.
4. Update `module/module.prop`:
   - `version=`
   - `versionCode=`
5. Update `update.json` with the same version, versionCode, release tag, and ZIP URL.
6. Update `CHANGELOG.md`.
7. Commit in GitHub Desktop.
8. Push to GitHub.
9. Create a GitHub Release using the matching tag, for example `v1.0.1`.
10. Upload the Magisk ZIP asset with the exact filename used in `update.json`.
11. Test Magisk update detection.

## Version rules

- Increase `versionCode` every release.
- Keep the logo path stable: `assets/logo.svg`.
- Keep runtime files under `/sdcard/Bluetooth-Stability-Helper/`.
- Keep Pokémon GO/Pokemod support package-name based only unless there is a specific reason to add a new package name.
- Do not add LSPosed/Vector hooks to this module. Keep it Magisk/system-side only.

## Monthly Pixel patch process

1. Check the installed device build ID, SDK, and security patch from diagnostics.
2. Add a new build-family guard only if Google changes Bluetooth, Companion Device, location, BLE, GATT, audio route, or background execution behaviour.
3. Prefer adaptive detection over hard-coded unreleased patch assumptions.
4. Release via GitHub Desktop + GitHub Releases so Magisk can update directly.
