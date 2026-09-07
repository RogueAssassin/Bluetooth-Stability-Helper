# Bluetooth Stability Helper Companion

The companion is the optional native Android presentation/support layer for Bluetooth Stability Helper. Recovery remains entirely inside the root module.

## Screens

- **Overview** — root/module/API state, health score, recovery state, Bluetooth state and heartbeat.
- **Activity** — newest bounded normalized engine events.
- **Device** — profile, device, Android/build/security-patch and supported-app context.
- **Support** — root provider, module enabled state, manager API schema/source and refresh state.

## Data access

The app detects the module independently from `/data/adb/modules/btstabilityhelper/module.prop`, then reads the canonical private schema-2 API. It falls back to the shared-storage API mirror when needed. Schema 1 remains accepted for migration compatibility.

Root access is restricted to fixed BSH paths. The app has no arbitrary shell UI and does not make Bluetooth recovery decisions.

## Signing and updates

Published companion APKs use one persistent BSH release certificate on both `testing` and `main`. CI fails if the signing identity is missing or changes. See [../docs/SIGNING.md](../docs/SIGNING.md).

v1.5/v1.6 used disposable debug signing, so an already-installed old companion may need to be removed once before installing the permanently signed v1.7+ app.

## Build

Release/package builds require the canonical signing environment:

```bash
gradle :app:verifyBshSigningConfigured :app:assembleRelease
```

Do not distribute a locally debug-signed APK as an update.
