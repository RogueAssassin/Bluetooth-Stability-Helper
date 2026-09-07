# Changelog

## v1.5.0
- Introduced the first native Bluetooth Stability Helper companion app under `companion-app/`.
- Added a Rogue-styled Android dashboard for health score, recovery state, OEM profile, Bluetooth process state and watchdog heartbeat.
- Added a recent-event timeline backed by bounded `metrics/events.jsonl` telemetry.
- Added a support view for module/API/root availability and recovery context.
- Kept the companion app read-only; recovery remains entirely inside the Magisk module.
- Added root-mediated reads of fixed BSH runtime files without broad storage permissions or arbitrary shell input.
- Reused the supplied full-quality BSH logo directly as the companion-app identity.
- Bundled the companion APK into the Magisk package and added install/update handling during module installation.
- Updated CI/release packaging so the module ZIP and release artifacts include the companion APK.
- Kept manager API schema version 1 compatible with the existing contract.

## v1.4.0-testing
- Added manager API schema v1 under `/sdcard/Bluetooth-Stability-Helper/api/` for the upcoming optional companion app.
- Added atomic read-only status, capabilities and config-schema JSON snapshots.
- Exposed health score, selected profile, recovery state, fault/outcome context, Bluetooth state, watchdog heartbeat and Android/build information through the manager contract.
- Published validated safe configuration ranges for future manager controls without permitting arbitrary shell execution.
- Integrated manager snapshots into the service loop, Magisk Action, diagnostics export and verification flow.
- Added `docs/MANAGER_API.md` defining the app/module boundary and security model.
- Kept the Magisk module fully standalone; no companion app is required for recovery or monitoring.

## v1.3.0
- Preserved bounded Bluetooth health and recovery history across reboot instead of deleting longitudinal diagnostics at every boot.
- Added watchdog PID, service-start and heartbeat state for detecting a stalled service process.
- Extended verification to distinguish a responsive watchdog from a process with a stale heartbeat.
- Added safe min/max validation for numeric shared-storage configuration overrides.
- Expanded diagnostics with watchdog heartbeat age and persistent recovery counts.
- Replaced legacy project graphics with the supplied full-resolution BSH banner and logo and removed superseded branding assets.
- Added explicit recovery states, normalized fault events and post-recovery verification while keeping existing cooldowns and conservative OEM profiles.
- Added bounded structured telemetry intended for diagnostics and a future optional companion manager app without introducing Zygisk/Xposed hooks.

## v1.2.0
- Replaced inactive legacy installer callbacks with a modern top-level `customize.sh` flow compatible with current Magisk module installation behaviour.
- Added a detailed install screen covering install/upgrade mode, root manager, device, Android build, security patch, SoC, ABI, SELinux, Bluetooth stack, app detection and selected recovery policy.
- Added transactional payload and shell-syntax verification before installation completes.
- Added persistent install and detected-profile reports, copied to the runtime folder after reboot.
- Preserved original-setting and idle-whitelist restoration data across module upgrades.
- Added active conservative profiles for Samsung, Xiaomi/Redmi/Poco, OnePlus/Oppo/Realme, Nothing, Motorola, ASUS/ROG, Sony Xperia and Vivo/iQOO.
- Added a diagnostic-only Huawei/Honor profile and automatic diagnostic fallback outside Android 12-17.
- Kept Google Pixel as the primary profile with the fastest evidence-based detection and strict Bluetooth process validation.
- Made non-Pixel process detection tolerant of vendor-specific Bluetooth process names.
- Expanded the Action screen and `verify.sh` with profile, service, recovery-policy, storage and Bluetooth health information.
- Added installation, verification and profile-selection coverage to the automated tests.

## v1.1.0
- Rebuilt the watchdog around fresh, concrete fault evidence instead of app-name matches or elapsed session time.
- Fixed the Android 17 profile that could toggle Bluetooth after eight minutes of otherwise healthy use.
- Added per-observer log-event signatures so the same old logcat line cannot repeatedly advance recovery.
- Raised Pixel recovery confirmation to two fresh failures, added a ten-minute cooldown, and capped refreshes at two per hour.
- Made Android 16/17 bond and Companion Device observations diagnostic-only; Android 17 autonomous re-pairing is no longer interrupted by the module.
- Disabled system-wide Wi-Fi scan throttling, location throttling, BLE-always-scan, A2DP offload changes, and forced AppOps by default.
- Limited default app targeting to the confirmed Pokémon GO and Pokemod packages.
- Replaced executable shared-storage configuration sourcing with a restricted scalar override parser.
- Added original-value backup and uninstall restoration for optional global settings, properties, and idle-whitelist entries.
- Removed ineffective dumpsys “keepalive” polling and reduced watchdog overhead.
- Centralised displayed version strings and corrected stale v1.0.4 labels.

## v1.0.5
- Added detailed install-time device, Android, root-manager, architecture, SELinux, build and OEM-profile reporting.
- Added installer payload validation before the root manager finalises installation.
- Added a standalone non-destructive `verify.sh` compatibility self-check.
- Added disabled/removal state guards and duplicate service-instance protection.
- Strengthened GitHub Actions validation and added release checksums.
- Preserved all Bluetooth recovery behaviour and the existing capped log system.
- No Play Integrity, spoofing, Zygisk injection, app hiding or device-identity features were added.

## v1.0.4 - Magisk updater metadata fix

- Bumped module to v1.0.4 / versionCode 1004.
- Fixed update manifest versionCode consistency so Magisk can detect updates correctly.
- Added workflow validation for module.prop, update.json, release tag, and release ZIP naming.
- No runtime Bluetooth or log-system changes.

## v1.0.3

- Added Pixel Android 17 July 2026 CP2A.260705 build-family awareness.
- Recognises CP2A.260705.006 / CP2A.260705.006.A1 as current Android 17 July Pixel firmware.
- Leaves the v1.0.2 capped/event-based log system unchanged.
- No aggressive Bluetooth behaviour changes required for this patch.

## v1.0.2

- Fixed runaway logging that could grow into multi-GB storage usage.
- Added boot cleanup for old logs and diagnostics exports.
- Added event-based logging so normal healthy watchdog loops stay quiet.
- Added aggressive log rotation and total log-folder storage cap.
- Capped diagnostics exports, Pixel connectivity snapshots, and recovery history.
- Disabled boot diagnostics export by default; diagnostics still export on important stalls/recoveries.
- Kept Pixel-first Android 12–17 Bluetooth stability engine, Pokémon GO, Pokemod, and VPGP³+ support.

## v1.0.1

- Promoted the project to the standard adaptive Bluetooth stability engine.
- Added Bluetooth health scoring and metrics export.
- Added monthly Pixel firmware/build/security-patch awareness without hard-coding unreleased updates.
- Kept Android 12-17 support with Pixel-first tuning.
- Kept Pokémon GO, Pokemod, and VPGP³+ support name/package based only, with no app-version lock-in.
- Added recovery history JSONL metrics.
- Retained GitHub updater, workflows, repo layout, logo, and `/sdcard/Bluetooth-Stability-Helper/` runtime paths.

## v0.10.0

- Added Android 17 / SDK 37 support range while retaining Android 12-16 behaviour.
- Added Pixel Android 17 adaptive guard for current Google firmware families.
- Added Android 17 Companion Device Manager, Nearby/Bluetooth permission, BLE privacy/RPA, background-audio, and memory-pressure observers.
- Tightened Pixel Android 17 VPGP³+ stale-session timing and keepalive intervals.
- Diagnostics now export Android 16/17 companion, role, permission, Bluetooth, location, and VPGP³+ signals.
- Repo style, GitHub updater, workflows, logo, and `/sdcard/Bluetooth-Stability-Helper/` runtime path retained.

## v0.9.2
- Adds Pixel Android 16 May 2026 CP1A.260505.005 build guard.
- Adds Android 16 companion-device, bond-loss, and encryption-change observers.
- Adds Pixel connectivity snapshots on stalls.
- Tightens Pixel CP1A stale-session recovery defaults while retaining Android 12-15 compatibility.

- Adds Interaction Freeze Guard for the exact symptom where Pokémon GO reaches a stop/Pokémon and the VPGP³+ interaction freezes while Bluetooth still appears connected.
- Tightens Pixel-first watchdog interval and recovery cooldown.
- Adds GMS/location keepalive polling while Pokémon GO/Pokemod/VPGP³+ style Bluetooth sessions are active.
- Improves Android 12-16 app idle, background, wakelock, Bluetooth scan/connect, and location appops handling.
- Keeps GitHub updater, repo layout, logo, and /sdcard/Bluetooth-Stability-Helper runtime path.

## v0.9.0
- Adaptive Bluetooth Stability Engine focused on Pixel, Android 12-16, Pokémon GO, Pokemod and VPGP³+.
