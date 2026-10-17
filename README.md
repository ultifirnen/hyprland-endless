# hyprland-endless

Tiling layout for Hyprland 0.56+ with a Lua config. Windows keep a minimum size: when they no longer fit, the workspace grows past the screen and the view follows the focused window instead of squeezing everything into thin strips.

## Install

    git clone <repo-url> && cd hyprland-endless && ./install.sh

The script copies endless.lua to ~/.config/hypr/ and appends the layout setting and keybinds to hyprland.lua. It works the same from fish, zsh and bash. Run it again after a git pull to update.

## Uninstall

    ./uninstall.sh

Then set general.layout back to the layout you used before.

## Keybinds

| Keys | Action |
| --- | --- |
| SUPER + CTRL + = | zoom in (bigger minimum window size) |
| SUPER + CTRL + - | zoom out (smaller minimum window size) |
| SUPER + CTRL + 0 | reset zoom |
| SUPER + CTRL + . | center the view on the focused window |
| SUPER + CTRL + J | toggle split direction of the focused window |
| SUPER + CTRL + ] / [ | grow / shrink the focused window |

## Layout messages

Sent with hl.dsp.layout: zoom in, zoom out, zoom reset, min W H, gap PX, follow on, follow off, center, grow, shrink, split.
