# STS Update Guide — GitHub Desktop Flow

This guide keeps the repo easy to maintain without Git Bash.

## Folder layout

```text
Bluetooth-Stability-Helper/
├── module/                   # Magisk install files
├── assets/logo.svg            # README logo; keep version-neutral
├── .github/workflows/         # package/release automation
├── update.json                # Magisk-compatible update manifest
├── CHANGELOG.md
├── README.md
└── STS_UPDATE_GUIDE.md
```

## Standard update process

1. Open **GitHub Desktop**.
2. Select `RogueAssassin/Bluetooth-Stability-Helper`.
3. Click **Fetch origin**.
4. Edit files in your normal editor.
5. Update these version fields:
   - `module/module.prop`
   - `update.json`
   - `CHANGELOG.md`
   - `README.md` download/version examples when needed
6. In GitHub Desktop, review the changed files.
7. Commit to `main`, for example:

```text
Release v0.8.1
```

8. Click **Push origin**.
9. Create a tag in GitHub Desktop:
   - Tag name: `v0.8.1`
   - Target: the release commit
10. Push the tag.
11. Open GitHub in your browser and check **Actions**.
12. When the release workflow finishes, open **Releases** and confirm the ZIP is attached.
13. Confirm Magisk update support:
   - `module/module.prop` has `updateJson=`
   - `update.json` has the latest `version`, `versionCode`, and `zipUrl`

## Version rules

- Increase `versionCode` every release.
- Use tags like `v0.8.1`, `v0.8.1`, `v0.9.0`.
- The GitHub tag must match `module.prop` version.
- Keep the logo version-neutral so it does not need changes every release.

## Local device config

Runtime files now live here:

```text
/sdcard/Bluetooth-Stability-Helper/
```

Use this file to change mode without pressing the Magisk Action button:

```text
/sdcard/Bluetooth-Stability-Helper/mode.txt
```

Recommended modes:

```text
pokemon
pixel
standard
safe
monitor
aggressive
diagnostics
```

## Troubleshooting release flow

If the release is missing:

1. Check the **Actions** tab.
2. Confirm the tag is pushed.
3. Confirm the tag is exactly `vX.Y.Z`.
4. Confirm `module/module.prop` says `version=X.Y.Z`.
5. Re-run the workflow from GitHub Actions if needed.

If Magisk does not show the update:

1. Confirm `updateJson=` in `module/module.prop` points to the raw GitHub `update.json`.
2. Confirm `update.json` points to the release asset ZIP.
3. Confirm `versionCode` is higher than the installed version.
