# Contributing

Thanks for contributing.

## Before opening a pull request

- Test on a non-critical device if possible.
- Include the exported `status.txt`.
- Include relevant excerpts from `bt-stability.log`.
- Note the phone brand, model, Android version, and Magisk version.
- Describe which mode was active.

## Development notes

- Keep `post-fs-data.sh` minimal.
- Prefer safer late-start logic in `service.sh`.
- Make vendor-specific changes opt-in or profile-gated.
- Avoid changes that can trigger boot loops.
- Keep Pokemod checks configurable and conservative by default.


## Companion signing

Do not commit keystores, passwords or private keys. Pull requests must not replace the canonical signing identity. Official package/release workflows use repository secrets and verify the APK certificate fingerprint before packaging. See [docs/SIGNING.md](docs/SIGNING.md).
