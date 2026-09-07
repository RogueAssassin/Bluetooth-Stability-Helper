# Bluetooth Stability Helper Manager API

Bluetooth Stability Helper 1.4 introduces a small, read-only data contract for the optional companion app. The Magisk module remains the root-side engine and continues to work completely without the app.

## Runtime path

```text
/sdcard/Bluetooth-Stability-Helper/api/
├── status.json
├── capabilities.json
└── config-schema.json
```

The current API schema is **1**.

## status.json

A periodically refreshed snapshot intended for a manager dashboard. It exposes module version, selected OEM profile, Bluetooth health score, recovery state, last fault, last recovery outcome, Bluetooth adapter/process health, watchdog heartbeat age, Android/build information, active supported apps, and paths to bounded event/recovery metrics.

## capabilities.json

Declares what the module exposes to a manager. The 1.4 contract is intentionally read-only. It does **not** expose arbitrary shell execution or remote root commands.

## config-schema.json

Documents the safe subset and min/max validation already enforced by the module's restricted `user-config.sh` parser. A future app can use this schema to render safe controls without guessing valid values.

## Security boundary

The manager contract is a presentation and support layer, not a second recovery engine. Bluetooth decisions remain in the Magisk service. The companion app should request root only for the minimum file access/actions it needs and must never execute unsanitized user input as shell.

Future write support should use explicit, allow-listed actions and transactional config updates rather than a generic command pipe.
