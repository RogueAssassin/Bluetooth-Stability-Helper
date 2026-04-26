#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}/..}
LOG="$MODDIR/bt-stability.log"
STATE_DIR="$MODDIR/state"
mkdir -p "$STATE_DIR"
log() { echo "$(date '+%F %T')  $1" >> "$LOG"; }
package_running() { pkg="$1"; [ -n "$pkg" ] || return 1; pidof "$pkg" >/dev/null 2>&1 && return 0; ps -A 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; ps 2>/dev/null | awk '{print $9}' | grep -qx "$pkg" && return 0; return 1; }
package_installed() { pkg="$1"; [ -n "$pkg" ] || return 1; cmd package path "$pkg" >/dev/null 2>&1 || pm path "$pkg" >/dev/null 2>&1; }
first_installed_from_list() { for pkg in $1; do package_installed "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
first_running_from_list() { for pkg in $1; do package_running "$pkg" && { echo "$pkg"; return 0; }; done; return 1; }
whitelist_pkg() { pkg="$1"; [ -n "$pkg" ] || return 0; cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1 && log "Whitelisted from idle: $pkg"; }
appops_allow_safe() { pkg="$1"; op="$2"; package_installed "$pkg" || return 0; cmd appops set "$pkg" "$op" allow >/dev/null 2>&1 && log "AppOps allow: $pkg $op"; }
