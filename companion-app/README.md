# Bluetooth Stability Helper Companion

The companion app is an optional native Android presentation and support layer for Bluetooth Stability Helper. It does **not** replace the Magisk module, perform Bluetooth recovery itself or expose a generic root shell.

## Current screens

- **Dashboard** — health score, recovery state, profile, Bluetooth process state, heartbeat, build and supported app/session state.
- **Timeline** — newest bounded normalized events from `metrics/events.jsonl`.
- **Support** — root/API availability, module version, profile and schema status.

## Data access

The app consumes manager API schema 1 and uses root only to read fixed BSH paths. It does not request broad shared-storage access and no user-provided value is executed as a root command.

## Build

From `companion-app/` run:

```bash
gradle :app:assembleDebug
```

GitHub Actions builds a debug APK for testing-branch app changes.
