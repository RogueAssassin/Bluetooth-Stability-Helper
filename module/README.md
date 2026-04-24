# Bluetooth Stability Helper v0.6.0

Author: RogueAssassin  
GitHub: https://github.com/RogueAssassin

This Magisk module focuses on conservative BLE/Bluetooth stability tuning,
status export, import/export bundles, safer recovery presets, and optional
Pokemod-aware health checks.

## v0.6.0 additions

- Added GitHub auto-update support through `updateJson` in `module.prop`.
- Added repo-ready `update.json`, `changelog.md`, and GitHub Actions release workflow.
- Added the current Pokemod public package name: `com.pokemod.app.public`.
- Kept Pokemod handling conservative: disabled by default and warn-only unless changed in `user-config.sh`.

## Pokemod checker

Example `user-config.sh` options:

```sh
POKEMOD_CHECK_ENABLED=1
POKEMOD_WARN_ONLY=1
POKEMOD_REQUIRED_FOR_GO=1
POKEMOD_PACKAGE_CANDIDATES="dev.pokemod com.pokemod com.pokemod.app com.pokemod.app.public com.pokemod.espresso com.roswell108.pokemodko"
POKEMON_GO_PACKAGE="com.nianticlabs.pokemongo"
```

Set `POKEMOD_WARN_ONLY=0` only if you want a missing Pokemod process to count as a watchdog failure and trigger the module's normal Bluetooth recovery logic after the configured failure threshold/cooldown.

## GitHub updater setup

The module currently points to:

```properties
updateJson=https://raw.githubusercontent.com/RogueAssassin/bt-stability-helper/main/update.json
```

If your repo name is different, edit `module.prop`, `update.json`, and `.github/workflows/release.yml` before publishing.

Recommended release flow:

1. Push this module folder to GitHub.
2. Enable GitHub Actions write permissions: Settings > Actions > General > Workflow permissions > Read and write permissions.
3. Create a tag such as `v0.6.0` and push it.
4. The workflow builds the Magisk zip and creates a GitHub Release.
5. Keep `update.json` in the default branch updated with the newest `version`, `versionCode`, and `zipUrl`.
