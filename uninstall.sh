#!/bin/sh
conf="$HOME/.config/hypr"
rm -f "$conf/endless.lua"
if [ -f "$conf/hyprland.lua" ]; then
tmp="$(mktemp)"
grep -vF -e "endless" -e "layout(\"zoom " -e "layout(\"center\")" -e "layout(\"split\")" -e "layout(\"grow\")" -e "layout(\"shrink\")" "$conf/hyprland.lua" > "$tmp" || true
cat "$tmp" > "$conf/hyprland.lua"
rm -f "$tmp"
fi
