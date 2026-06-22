# STS Update Guide - GitHub Desktop Flow

This project is designed for GitHub Desktop, not Git Bash.

## Future update steps

1. Open the repo in **GitHub Desktop**.
2. Replace/update files in the repo using File Explorer.
3. Update these version fields:
   - `module/module.prop`
   - `update.json`
   - `CHANGELOG.md`
   - README version notes if needed
4. Commit in GitHub Desktop with a clear message, for example:

```text
Update Bluetooth Stability Helper to v0.10.0
```

5. Push origin from GitHub Desktop.
6. In GitHub Desktop, create a tag matching the release version, for example:

```text
v0.10.0
```

7. Push the tag.
8. Open GitHub Releases in the browser and create a release from that tag.
9. Upload the Magisk install ZIP asset, for example:

```text
bt-stability-helper-v0.10.0.zip
```

10. Confirm `update.json` points to the same release asset URL.

## Rules

- Always increase `versionCode`.
- Keep the source repo layout the same.
- Keep runtime files under `/sdcard/Bluetooth-Stability-Helper/`.
- Do not add Vector/LSPosed hooks to this Magisk module.
- Do not put version numbers inside the logo so it does not need changing every release.
