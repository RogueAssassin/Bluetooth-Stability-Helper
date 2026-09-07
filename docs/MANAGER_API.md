# Bluetooth Stability Helper Manager API

Bluetooth Stability Helper exposes a small, read-only data contract for the optional companion app. The Magisk module remains the root-side recovery engine and works without the app.

## Runtime paths

The canonical API is private to the root module:

```text
/data/adb/modules/btstabilityhelper/runtime/api/
├── status.json
├── capabilities.json
└── config-schema.json
```

A best-effort human/support mirror is also written to:

```text
/sdcard/Bluetooth-Stability-Helper/api/
```

The current API schema is **3**. The v1.8 companion accepts schemas 1–3 for migration compatibility.

## status.json

The periodically refreshed atomic snapshot exposes module identity/version, BOOTING/READY service lifecycle and uptime, root/Zygisk environment, selected OEM profile, Bluetooth health score, recovery state, last fault/recovery outcome, adapter/process health, watchdog heartbeat age, Android/device/build/security-patch information, active supported apps, and the effective bounded watchdog/recovery settings.

## capabilities.json

Declares the read-only manager capabilities and the canonical/mirror locations. It explicitly disables arbitrary shell and remote command support.

## config-schema.json

Documents the safe configuration subset and min/max validation enforced by the restricted `user-config.sh` parser. It is descriptive in v1.7; the app does not write root configuration.

## Security boundary

The app requests root only for fixed BSH paths. Bluetooth decisions stay in the Magisk service. There is no terminal, generic command pipe, Zygisk/Xposed bridge or arbitrary user-provided root command.

Future write support must use explicit allow-listed actions and transactional configuration changes.
