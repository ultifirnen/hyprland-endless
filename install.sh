#!/bin/sh
set -e
dir="$(cd "$(dirname "$0")" && pwd)"
conf="$HOME/.config/hypr"
mkdir -p "$conf"
cp "$dir/endless.lua" "$conf/endless.lua"
if ! grep -q "endless.lua" "$conf/hyprland.lua" 2>/dev/null; then
cat >> "$conf/hyprland.lua" <<"EOF"

dofile(os.getenv("HOME") .. "/.config/hypr/endless.lua")
hl.config({ general = { layout = "lua:endless" } })
hl.bind("SUPER + CTRL + equal", hl.dsp.layout("zoom in"))
hl.bind("SUPER + CTRL + minus", hl.dsp.layout("zoom out"))
hl.bind("SUPER + CTRL + 0", hl.dsp.layout("zoom reset"))
hl.bind("SUPER + CTRL + F", hl.dsp.layout("zoom fit"))
hl.bind("SUPER + CTRL + period", hl.dsp.layout("center"))
hl.bind("SUPER + CTRL + J", hl.dsp.layout("split"))
hl.bind("SUPER + CTRL + bracketright", hl.dsp.layout("grow"))
hl.bind("SUPER + CTRL + bracketleft", hl.dsp.layout("shrink"))
EOF
fi
