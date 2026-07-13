#!/system/bin/sh
# Bluetooth Stability Helper v1.2.0 defaults.
# Override in /sdcard/Bluetooth-Stability-Helper/user-config.sh
# Design goal: one adaptive Bluetooth stability engine, Pixel-first, Pokémon GO/Pokemod aware.
# v1.2.0 uses evidence-based recovery: passive observation first, fresh
# fault signals before recovery, and no elapsed-time-only Bluetooth toggles.

WATCHDOG_ENABLED=1
WATCHDOG_INTERVAL=25
# Logging safety. Keep the phone storage clean and avoid performance issues from runaway logs.
# Logs are event-based by default, cleared on boot, rotated aggressively, and capped.
LOG_IMPORTANT_ONLY=1
LOG_DEDUP_SECONDS=300
LOG_BOOT_CLEAN=1
LOG_ROTATE_SIZE_KB=256
LOG_KEEP_ROTATED_COUNT=2
LOG_MAX_TOTAL_MB=10
EXPORT_MAX_FILES=8
METRICS_MAX_KB=512
SNAPSHOT_MAX_FILES=4
LOGCAT_CAPTURE_LINES=80
LOGCAT_CAPTURE_WINDOW_SECONDS=180
MAX_RESTARTS_PER_HOUR=2
FAILURE_THRESHOLD=2
FAILURE_WINDOW_SECONDS=180
RECOVERY_COOLDOWN=600
FRESH_FAULT_MAX_AGE_SECONDS=180

# Android support range. 31=A12, 32=A12L, 33=A13, 34=A14, 35=A15, 36=A16, 37=A17.
SUPPORTED_SDK_MIN=31
SUPPORTED_SDK_MAX=37
ANDROID16_SDK=36
ANDROID17_SDK=37
ENABLE_ANDROID_VERSION_WARNINGS=1
ENABLE_SDK_AWARE_TUNING=1


# Pixel Android 16 May 2026 build guard. CP1A.260505.005 is the May 2026 Pixel Android 16 QPR3 build.
PIXEL_ANDROID16_MAY2026_BUILD_PREFIX="CP1A.260505"
ENABLE_PIXEL_MAY2026_CP1A_GUARD=1
ENABLE_PIXEL_CONNECTIVITY_SNAPSHOT_ON_STALL=1
PIXEL_CP1A_WATCHDOG_INTERVAL=25
PIXEL_CP1A_RECOVERY_COOLDOWN=600
PIXEL_CP1A_STALE_SESSION_MINUTES=20
PIXEL_CP1A_FAILURE_THRESHOLD=2

# Android 16 connectivity changes to observe, not override.
ENABLE_ANDROID16_BOND_LOSS_OBSERVE=1
ENABLE_ANDROID16_JOB_STANDBY_GUARD=1

# Android 17 / Pixel firmware guard. Detection is SDK-first because stable and
# QPR build families vary by device/channel. CP31 covers the current QPR1 line.
PIXEL_ANDROID17_KNOWN_BUILD_PREFIXES="CP21 CP2A CP31 AP3A BP3A"
PIXEL_ANDROID17_JULY2026_BUILD_PREFIX="CP2A.260705"
ENABLE_PIXEL_ANDROID17_GUARD=1
PIXEL_ANDROID17_WATCHDOG_INTERVAL=25
PIXEL_ANDROID17_RECOVERY_COOLDOWN=600
PIXEL_ANDROID17_STALE_SESSION_MINUTES=20
PIXEL_ANDROID17_FAILURE_THRESHOLD=2

# Health metrics record build and security-patch drift without hard-coding
# recovery behaviour to one firmware identifier.
ENABLE_BLUETOOTH_HEALTH_SCORE=1
HEALTH_SCORE_EXPORT_INTERVAL=60


# Recovery ladder. Defaults diagnose first and only refresh after confirmed,
# fresh fault evidence. App processes are never killed by default.
ENABLE_AUDIO_ROUTE_REPAIR=1
ENABLE_BT_PROCESS_CHECK=1
ENABLE_STRICT_BT_PROCESS_CHECK=1
ENABLE_BT_MANAGER_CHECK=1
ENABLE_ADAPTER_TOGGLE_RECOVERY=1
ENABLE_BLUETOOTH_APP_FORCE_STOP=0
ENABLE_A2DP_OFFLOAD_DISABLE=0

# Pixel remains the primary profile. Other OEM profiles use conservative
# recovery settings and do not change vendor properties by default.

# Pokémon GO / Pokemod / VPGP³+ support checker. Name/package detection only; no app-version lock-in.
POKEMON_GO_PACKAGE_CANDIDATES="com.nianticlabs.pokemongo"
POKEMOD_CHECK_ENABLED=1
POKEMOD_REQUIRED_FOR_GO=0
POKEMOD_WARN_ONLY=1
POKEMOD_PACKAGE_CANDIDATES="com.pokemod.app.public"
VPGP3_DISPLAY_NAME="VPGP³+"
VPGP3_PACKAGE_CANDIDATES=""
BLUETOOTH_GAME_PACKAGE_CANDIDATES="com.nianticlabs.pokemongo com.pokemod.app.public"

# VPGP³+ stale-session watchdog. Designed for the symptom: catches/spins for a while, then session stalls.
ENABLE_STALE_SESSION_WATCHDOG=1
STALE_SESSION_MINUTES=20
STALE_SESSION_ACTION="diagnose"   # log | diagnose; time alone never refreshes Bluetooth
STALE_SESSION_BT_REFRESH=0
POKEMONPLUS_AUTO_EXPORT_ON_STALL=1
ENABLE_GO_PLUS_STALL_PATTERNS=1

# Interaction freeze guard: targets the symptom where Pokémon GO reaches a stop/Pokémon,
# VPGP³+ begins the interaction, then the interaction freezes while BT remains connected.
ENABLE_INTERACTION_FREEZE_GUARD=1
INTERACTION_FREEZE_WINDOW_SECONDS=300
INTERACTION_FREEZE_RECOVERY_AFTER_MATCHES=1

# Location/Bluetooth setting checks. Most are safe appops/device-idle tuning.
WHITELIST_BLUETOOTH=0
WHITELIST_GMS=0
WHITELIST_POKEMON_GO=1
WHITELIST_POKEMOD=1
WHITELIST_EXTRA_PACKAGES=""
ENABLE_DEVICE_IDLE_TUNING=0
DEVICE_IDLE_CONSTANTS="inactive_to=86400000,sensing_to=600000,locating_to=600000"
ENABLE_WIFI_SCAN_THROTTLE_OFF=0
ENABLE_LOCATION_BG_THROTTLE_OFF=0
ENABLE_BLE_SCAN_ALWAYS=0
CHECK_LOCATION_MODE=1
CHECK_BLE_SCAN_SETTINGS=1
APPLY_APP_OPS_FIXES=0
APPLY_RESTRICTED_STANDBY_FIXES=1

# Local files live directly under /sdcard, not Downloads.
CONFIG_DIR="/sdcard/Bluetooth-Stability-Helper"
IMPORT_DIR="$CONFIG_DIR/import"
EXPORT_DIR="$CONFIG_DIR/export"
LOG_DIR="$CONFIG_DIR/logs"
STATE_DIR="$CONFIG_DIR/state"
LOCAL_USER_CONFIG="$CONFIG_DIR/user-config.sh"
LOCAL_STATUS_FILE="$CONFIG_DIR/status.txt"
