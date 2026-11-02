#!/system/bin/sh

# Per-generation overrides for Pixel devices.
#
# IMPORTANT: this is deliberately a no-op by default. The shared Pixel policy
# below is validated and conservative; we do NOT invent different recovery
# thresholds per generation without real per-device evidence. Generation and
# SoC era are detected and reported so diagnostics can be bucketed by hardware,
# which is the prerequisite for ever tuning a generation on evidence. When a
# generation has a documented, data-backed reason to differ, add it here as a
# case and nowhere else; until then every generation keeps the proven policy.
apply_pixel_generation_overrides() {
  case "$PIXEL_GENERATION" in
    6|7) : ;;   # early-tensor (Exynos-modem era): reported; policy unchanged
    8|9) : ;;   # mid-tensor: reported; policy unchanged
    1[0-9]) : ;; # current-tensor (incl. confirmed Pixel 10 frankel): unchanged
    *) : ;;     # unknown generation: safe shared Pixel policy
  esac
}

apply_profile_pixel() {
  apply_profile_generic_defaults
  PROFILE_ID="pixel"
  PIXEL_GENERATION=$(pixel_generation)
  PIXEL_SOC_ERA=$(pixel_soc_era)
  if [ "$PIXEL_GENERATION" != 0 ]; then
    PROFILE_LABEL="Google Pixel primary (gen ${PIXEL_GENERATION}, ${PIXEL_SOC_ERA})"
  else
    PROFILE_LABEL="Google Pixel primary"
  fi
  WATCHDOG_INTERVAL=25
  FAILURE_THRESHOLD=2
  FAILURE_WINDOW_SECONDS=180
  RECOVERY_COOLDOWN=600
  MAX_RESTARTS_PER_HOUR=2
  STALE_SESSION_MINUTES=20
  ENABLE_STRICT_BT_PROCESS_CHECK=1

  if [ "$ENABLE_PIXEL_ANDROID17_GUARD" = 1 ] && is_pixel_android17; then
    WATCHDOG_INTERVAL="$PIXEL_ANDROID17_WATCHDOG_INTERVAL"
    RECOVERY_COOLDOWN="$PIXEL_ANDROID17_RECOVERY_COOLDOWN"
    STALE_SESSION_MINUTES="$PIXEL_ANDROID17_STALE_SESSION_MINUTES"
    FAILURE_THRESHOLD="$PIXEL_ANDROID17_FAILURE_THRESHOLD"
    log "Pixel Android 17 guard: build=$(build_id) known_family=$(is_known_pixel_android17_build_family && echo yes || echo no)"
    is_android_preview_build && log "Pixel Android 17 guard: preview/beta firmware detected; policy unchanged"
  elif [ "$ENABLE_PIXEL_MAY2026_CP1A_GUARD" = 1 ] && is_pixel_android16_may2026; then
    WATCHDOG_INTERVAL="$PIXEL_CP1A_WATCHDOG_INTERVAL"
    RECOVERY_COOLDOWN="$PIXEL_CP1A_RECOVERY_COOLDOWN"
    STALE_SESSION_MINUTES="$PIXEL_CP1A_STALE_SESSION_MINUTES"
    FAILURE_THRESHOLD="$PIXEL_CP1A_FAILURE_THRESHOLD"
    ENABLE_ANDROID16_BOND_LOSS_OBSERVE=1
    log "Pixel Android 16 CP1A guard: build=$(build_id)"
  fi
  apply_pixel_generation_overrides
  log "Device profile: $PROFILE_LABEL"
}
