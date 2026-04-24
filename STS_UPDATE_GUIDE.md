# STS Update Guide

Use this guide every time you prepare a new Bluetooth Stability Helper release.

## 1. Choose the next version

Use semantic-style versions:

- Patch fix: `0.6.1`
- Minor feature release: `0.7.0`
- Major breaking change: `1.0.0`

Always increase `versionCode` in `module/module.prop` and `update.json`. Suggested pattern:

```text
0.6.0 -> versionCode 60
0.6.1 -> versionCode 61
0.7.0 -> versionCode 70
1.0.0 -> versionCode 100
```

## 2. Update module metadata

Edit `module/module.prop`:

```properties
version=0.6.1
versionCode=61
updateJson=https://raw.githubusercontent.com/RogueAssassin/Bluetooth-Stability-Helper/main/update.json
```

Do not change the `id` unless you intentionally want Magisk to treat it as a different module.

## 3. Update the GitHub updater manifest

Edit root `update.json`:

```json
{
  "version": "0.6.1",
  "versionCode": 61,
  "zipUrl": "https://github.com/RogueAssassin/Bluetooth-Stability-Helper/releases/download/v0.6.1/bt-stability-helper-v0.6.1.zip",
  "changelog": "https://raw.githubusercontent.com/RogueAssassin/Bluetooth-Stability-Helper/main/CHANGELOG.md"
}
```

The `zipUrl` must exactly match the zip uploaded by the release workflow.

## 4. Update the changelog

Add the new version to the top of `CHANGELOG.md`. Keep the most recent release at the top.

## 5. Check the module layout

```text
Bluetooth-Stability-Helper/
├── .github/workflows/package.yml
├── .github/workflows/release.yml
├── assets/logo.svg
├── assets/screenshots/
├── module/
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── STS_UPDATE_GUIDE.md
└── update.json
```

Only the contents of `module/` go inside the Magisk install zip.

## 6. Build locally before tagging

```bash
cd module
zip -r ../bt-stability-helper-v0.6.1.zip .
cd ..
unzip -l bt-stability-helper-v0.6.1.zip | head
```

Confirm `module.prop` is at the top level of the zip. The zip should not contain a parent `module/` folder.

## 7. Test before release

Install the local zip in Magisk and reboot. Then check:

```text
/data/adb/modules/btstabilityhelper/module.prop
/data/adb/modules/btstabilityhelper/bt-stability.log
/sdcard/Download/Bluetooth-Stability-Helper/export/status.txt
```

Minimum release test:

- Device boots normally.
- Magisk shows the new version.
- Action button exports status.
- Bluetooth still starts normally.
- Pokemod package candidates include `com.pokemod.app.public`.
- No boot loop, repeated restart loop, or runaway log spam.

## 8. Commit the release files

```bash
git add module/module.prop update.json CHANGELOG.md README.md STS_UPDATE_GUIDE.md .github assets
git commit -m "Release v0.6.1"
git push origin main
```

## 9. Create and push the release tag

```bash
git tag v0.6.1
git push origin v0.6.1
```

The release workflow will create a GitHub Release and upload `bt-stability-helper-v0.6.1.zip`.

## 10. Verify GitHub release and updater

After the workflow finishes, confirm the release asset exists, `update.json` points to it, and the uploaded zip installs.

## 11. Emergency rollback

If a bad release ships, restore `update.json` to the last known-good version, then ship a new fixed patch release. Never reuse a tag after users may have downloaded it.

## 12. Common mistakes to avoid

- Do not zip the parent `module/` folder.
- Do not forget to increase `versionCode`.
- Do not let `update.json` point to an asset name that the workflow does not create.
- Do not rename the Magisk module `id` casually.
- Do not enable aggressive watchdog options by default.
