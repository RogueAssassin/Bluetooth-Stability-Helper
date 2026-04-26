# STS Update Guide

## Standard release path

1. Edit `module/module.prop`:
   - `version=x.y.z`
   - `versionCode=` must increase.
2. Update `update.json` with the same version and the GitHub Release ZIP URL.
3. Update `CHANGELOG.md`.
4. Test locally by installing the module zip in Magisk.
5. Push to GitHub.
6. Create a tag such as `v0.7.1`.
7. GitHub Actions builds the install zip and attaches it to the release.
8. Confirm Magisk sees the update from `updateJson`.

## Changing mode without Magisk Action

Create this file on device:

```text
/sdcard/Download/Bluetooth-Stability-Helper/mode.txt
```

Put one mode in the file:

```text
pokemon
```

The service rereads it during the watchdog loop.

## Recommended production settings

Start with:

```text
standard
```

For Pokémon GO + Pokemod/vPGP3 sessions, use:

```text
pokemon
```

Only use `aggressive` if dropouts continue after collecting diagnostics.

## Debug bundle

Magisk Action exports:

```text
/sdcard/Download/Bluetooth-Stability-Helper/export/status.txt
/sdcard/Download/Bluetooth-Stability-Helper/export/log-tail.txt
```
