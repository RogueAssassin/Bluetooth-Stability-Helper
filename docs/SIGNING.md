# Companion App Signing

Bluetooth Stability Helper uses one persistent Android signing identity for the companion app. Android requires every update to the same package name (`com.rogueassassin.bsh`) to be signed by the same certificate.

## Required GitHub Actions secrets

Configure these repository secrets once and preserve them for the lifetime of the app:

- `BSH_SIGNING_KEYSTORE_BASE64` — base64 of the private JKS/PKCS12 keystore.
- `BSH_SIGNING_STORE_PASSWORD` — keystore password.
- `BSH_SIGNING_KEY_ALIAS` — signing-key alias.
- `BSH_SIGNING_KEY_PASSWORD` — private-key password.
- `BSH_SIGNING_CERT_SHA256` — SHA-256 fingerprint of the public signing certificate, with or without colons.

The private keystore must never be committed to this repository. Keep an offline encrypted backup. Losing it prevents future in-place Android updates; replacing it changes the app identity from Android's perspective.

## CI enforcement

All companion, package and stable-release workflows restore the same keystore, build the release APK, then use Android `apksigner` to compare the produced certificate fingerprint with `BSH_SIGNING_CERT_SHA256`. A missing secret or fingerprint mismatch fails the build before a Magisk ZIP or GitHub Release can be published.

Both `main` and `testing` therefore use the same app certificate. Branches change software version/channel, not signing identity.

## v1.5/v1.6 migration

v1.5.0 and v1.6.0 were produced with disposable GitHub Actions debug signing. Those certificates cannot be recreated unless the original private debug keystore still exists.

The first permanently signed release therefore requires a one-time removal of an already-installed old companion APK if Android reports `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. The Magisk module and `/sdcard/Bluetooth-Stability-Helper/` runtime data are separate and remain intact.

After the device has installed the permanently signed companion, v1.7.0 and all later releases can update it normally as long as the same signing secrets are retained.

## Local release build

Provide the same four signing environment variables and run:

```bash
gradle :app:verifyBshSigningConfigured :app:assembleRelease
```

Do not publish locally signed APKs unless they use the canonical BSH release key.
