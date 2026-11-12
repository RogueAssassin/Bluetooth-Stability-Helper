# Changelog

## v1.11.2
- Security: moved runtime state from `/sdcard/Bluetooth-Stability-Helper/state/` to the root-only `/data/adb/bsh-state/`. The validated config copy that the root service sources was previously written to shared storage, where an app with broad storage access could have replaced it between validation and sourcing. Fault counters, cooldown and restart history are no longer app-writable either.
- The legacy shared-storage `state/` directory is removed at service start; counters reset once after updating. Logs, metrics, exports, the API mirror and `user-config.sh` stay under `/sdcard`.
- Uninstall now removes `/data/adb/bsh-state`. The companion app reads the diagnostic-bundle pointer from the private location.
- Performance: the watchdog now takes one `dumpsys bluetooth_manager` snapshot per tick and reuses it for the manager check, ACL observer, health score and connectivity snapshot (previously three to six calls per tick); recovery verification refreshes it explicitly.
- CI hardening: third-party and first-party actions are pinned to commit SHAs (Dependabot now also tracks the composite action), `package` and `companion-app` run with a read-only token, and the release job alone holds `contents: write`.
- CI: a push to `main` that does not change the module version now skips the release with a notice instead of failing on the existing tag; changes under `.github/actions/` trigger the workflows that use them.
- Docs: `docs/SIGNING.md` describes where the signing identity is enforced in CI and on device.

## v1.11.1
- Build/CI only: extracted the duplicated companion-app signing sequence (toolchain setup, keystore restore, signed build, certificate SHA-256 verification) into a shared `.github/actions/build-signed-companion` composite action used by the companion-app, package and release workflows. No module or app behavior change.

## v1.11.0
- Added Pixel hardware generation detection, parsed from the model name (e.g. `Pixel 10`, `Pixel 9 Pro XL`, `Pixel 6a` → 10/9/6) with a confirmed `frankel` = Pixel 10 codename fallback, plus a coarse SoC-era grouping (early/mid/current-tensor).
- Report `pixel_generation` and `pixel_soc_era` in `status.txt`, the manager API (additive fields; schema remains 3) and the companion Device view.
- Restructured the Pixel profile with `apply_pixel_generation_overrides()`. It is intentionally a no-op: the validated conservative Pixel policy is identical across generations. Per-generation recovery thresholds are not invented without real per-device evidence; detection/reporting is the prerequisite for bucketing diagnostics by hardware so a generation can later be tuned on data.
- Added tests for generation/SoC parsing across Pixel models and non-Pixel devices.

## v1.10.0
- Added an ACL link-instability observer: it counts abnormal ACL disconnects (`reason:8` connection/supervision timeout, `reason:34` LL response timeout, and the configurable `11`/`40`/`61`) reported by `dumpsys bluetooth_manager` while the adapter stays ON. Benign reasons such as `19` (remote user terminated) and `22` (local host terminated) are never counted.
- New disconnects are detected by anchoring on the previously seen newest line, so the bounded dump ring buffer cannot be double-counted; the first scan only establishes a baseline and a per-tick cap bounds buffer rollovers. This targets the common Pixel symptom where the HAL never crashes but the link keeps flapping, which the existing log-pattern observers did not catch.
- The observer is observe-only by default (`ACL_INSTABILITY_RECOVERY_ENABLED=0`): it records a fault event and a health-score penalty but does not toggle the adapter unless explicitly opted in, consistent with not fighting the platform's own recovery.
- Added a weighted health score with a `components` breakdown and `acl_abnormal_window_count` in `metrics/bluetooth-health.json`, so diagnostics and the companion app can show why a device is degraded.
- Added additive `acl_instability` status fields and `acl_instability`/`health_components` capability flags to the manager API. The schema number remains 3 and existing managers (which accept schema 1–3) keep working.
- Added safe, range-validated user overrides: `ENABLE_ACL_INSTABILITY_GUARD`, `ACL_INSTABILITY_WINDOW_SECONDS`, `ACL_INSTABILITY_THRESHOLD`, `ACL_INSTABILITY_MAX_NEW_PER_TICK`, `ACL_INSTABILITY_RECOVERY_ENABLED`, `ACL_ABNORMAL_DISCONNECT_REASONS` and `WATCHDOG_JITTER_SECONDS`.
- Added watchdog sleep jitter (`WATCHDOG_JITTER_SECONDS`, default 5) so repeated wakeups do not synchronise with other periodic work.
- Hardened metric-count reads in the health export against a missing history file.
- Expanded the test suite with ACL parsing, delta/window/penalty and additive manager-API contract checks.
- Companion app redesigned on Material 3 with Material You dynamic color (device accent) on Android 12+, a dark-first Rogue fallback palette and system light/dark support.
- Overview now leads with a health hero card and an animated status ring, a "Why this score" per-signal component breakdown (read from `metrics/bluetooth-health.json`), and an ACL link-stability card showing abnormal disconnects against the threshold with guard/observe state.
- Companion app parses the additive `acl_instability` status fields and health-component breakdown, ignoring them when absent so it stays compatible with older engine builds.
- Companion version bumped to 1.10.0 (versionCode 2000).

## v1.9.0
- Recognised the current Pixel Android 17 firmware families: the October 2026 `CP3A.261005` line (Pixel 6 through Pixel 10a) and the Pixel 11 series `CD1A` line.
- Added preview/beta firmware detection (non-REL codename or Android 17 QPR3 beta `DP11` builds). It is reported in the status file, manager API and companion app without changing recovery policy.
- Added additive `android_codename` and `android_preview_build` fields to the manager API status snapshot (schema remains 3).
- Fixed APatch being reported as KernelSU in the installer and companion app when both markers are present.
- Added an installer notice when Magisk is older than 28.0, which lacks module Action button support.
- Companion app now targets and compiles against Android 17 (API 37) with explicit edge-to-edge handling.
- Upgraded the companion toolchain to Android Gradle Plugin 9.4 with built-in Kotlin, Kotlin 2.4.20, Gradle 9.8.1 and the 2026.09 Compose BOM.
- Updated CI to current action releases and JDK 21, and run packaging checks on pull requests.

## v1.8.0
- Added Manager API schema 3 with BOOTING/READY lifecycle, service uptime, root environment, expanded device/build metadata and effective recovery settings.
- Publish an initial manager snapshot during module startup and refresh the complete READY snapshot after Android boot/profile initialization.
- Expanded the companion Device view with manufacturer, brand/model, build fingerprint, root/Zygisk, service uptime and effective engine policy.
- Added API freshness/stale reporting to the companion support surface.
- Added a companion-triggered, fixed root diagnostic action and timestamped sanitized support bundles.
- Added local diagnostic progress/result reporting and explicit privacy guidance.
- Hardened API JSON generation and expanded CI contract tests for schema 3.
- Retained permanent companion signing and certificate verification across testing/stable packages.

## v1.7.0
- Established one persistent companion-app signing identity for both testing and stable releases.
- Changed CI/package/release builds from disposable debug APKs to signed release APKs.
- Added mandatory signing-secret validation and SHA-256 certificate fingerprint verification before packaging.
- Added a hard CI failure when the signing identity is missing or changes, preventing accidental incompatible APK releases.
- Documented the one-time migration required for v1.5/v1.6 debug-signed companion installations.
- Improved module installer reporting for Android signature mismatch failures without removing app data automatically.
- Added a lightweight two-minute service self-check for runtime state/metrics writability and abnormal Bluetooth-process loss.
- Added bounded service-health telemetry while preserving the existing evidence-based recovery ladder and avoiding a second restart loop.
- Extended runtime verification with service self-check status.
- Removed stale version labels from module defaults and refreshed architecture, API, module, companion, signing and contribution documentation.

## v1.6.0
- Fixed the companion app falsely reporting the module as missing when only the shared-storage manager API snapshot was unavailable.
- Moved the canonical manager API to the private Magisk module tree under `/data/adb/modules/btstabilityhelper/runtime/api/`.
- Kept a best-effort mirror under `/sdcard/Bluetooth-Stability-Helper/api/` for human diagnostics and support.
- Added independent module detection from `module.prop`, including enabled/disabled state, before any manager API lookup.
- Added manager API fallback logic: private API first, shared-storage mirror second.
- Bumped the manager API to schema 2 with explicit module/device/Android metadata while retaining app compatibility with schema 1.
- Forced an API snapshot immediately after boot initialization instead of waiting for the first watchdog refresh interval.
- Revamped the companion app into Overview, Activity, Device and Support surfaces.
- Added ROOT / MODULE / API status indicators, a larger health state card, device/build details, API source reporting and clearer failure messages.
- Added automatic 30-second app refresh while keeping manual refresh controls.
- Kept recovery logic exclusively in the Magisk module and preserved the read-only app security boundary.

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
