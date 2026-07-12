#!/system/bin/sh
MODDIR=${0%/*}
# Leave /sdcard/Bluetooth-Stability-Helper in place so diagnostics are not lost.
# Restore only values this installation recorded before changing them.
backup="$MODDIR/state/original-global-settings.txt"
if [ -f "$backup" ]; then
  while IFS='|' read -r key value; do
    [ -n "$key" ] || continue
    if [ "$value" = "null" ]; then
      settings delete global "$key" >/dev/null 2>&1
    else
      settings put global "$key" "$value" >/dev/null 2>&1
    fi
  done < "$backup"
fi

props="$MODDIR/state/original-properties.txt"
if [ -f "$props" ]; then
  while IFS='|' read -r key value; do
    [ -n "$key" ] || continue
    if [ "$value" = "__EMPTY__" ]; then
      resetprop -p --delete "$key" >/dev/null 2>&1 || resetprop --delete "$key" >/dev/null 2>&1
    else
      resetprop -n "$key" "$value" >/dev/null 2>&1
    fi
  done < "$props"
fi

whitelist="$MODDIR/state/added-idle-whitelist.txt"
if [ -f "$whitelist" ]; then
  sort -u "$whitelist" 2>/dev/null | while IFS= read -r pkg; do
    [ -n "$pkg" ] && cmd deviceidle whitelist -"$pkg" >/dev/null 2>&1
  done
fi
