# Bluetooth Stability Helper Module

This folder is the root of the installable Magisk/KernelSU/APatch module payload.

## Runtime

The root engine starts from `service.sh` after Android completes boot, selects an OEM/Android profile, loads validated scalar overrides, observes Bluetooth/BLE/GATT evidence and uses the bounded recovery state machine.

Persistent user/support data lives under:

```text
/sdcard/Bluetooth-Stability-Helper/
```

The canonical companion API lives privately under:

```text
/data/adb/modules/btstabilityhelper/runtime/api/
```

v1.7 adds a lightweight runtime self-check that reports repeated storage/process degradation through telemetry without creating a second recovery loop.

## Companion

`companion.apk` is injected by CI into the module ZIP. Production packages must use the persistent BSH signing identity documented in `docs/SIGNING.md`. The installer attempts `pm install -r`; an old debug-signed v1.5/v1.6 companion may require a one-time uninstall before the permanently signed app can be installed.

Only this directory's packaged contents belong at the root of the flashable ZIP. GitHub's source archive is not a Magisk module.
