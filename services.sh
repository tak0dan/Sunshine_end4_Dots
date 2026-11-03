#!/usr/bin/env bash
# Make sure everything this setup relies on is installed, enabled and running.
# Safe to run any number of times.
#
# Usage: services.sh [--check]
#   --check   only report, change nothing

set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
check=false
[[ ${1:-} == --check ]] && check=true

ok=0 fixed=0 bad=0
green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' rst=$'\e[0m'
pass() { printf '  %s✓%s %s\n' "$green" "$rst" "$1"; ok=$((ok + 1)); }
fix()  { printf '  %s↻%s %s\n' "$yellow" "$rst" "$1"; fixed=$((fixed + 1)); }
fail() { printf '  %s✗%s %s\n' "$red" "$rst" "$1"; bad=$((bad + 1)); }

user_unit_exists() { systemctl --user cat "$1" &>/dev/null; }

ensure_user_service() {
    local unit=$1
    if systemctl --user is-enabled -q "$unit" && systemctl --user is-active -q "$unit"; then
        pass "$unit enabled and running"
    elif $check; then
        fail "$unit is not enabled/running"
    elif systemctl --user enable --now "$unit" &>/dev/null; then
        fix "$unit enabled and started"
    else
        fail "$unit could not be started (see: systemctl --user status $unit)"
    fi
}

echo "Services"

# 1. per-window keyboard layout listener (this setup)
unit=tak0-per-window-switch.service
dst=$config/systemd/user/$unit
if [[ ! -f $config/hypr/scripts/Tak0-Per-Window-Switch.py ]]; then
    fail "$unit: ~/.config/hypr/scripts/Tak0-Per-Window-Switch.py is missing (run install.sh)"
elif ! cmp -s "$here/systemd/$unit" "$dst"; then
    if $check; then
        fail "$unit is not installed (or differs from the repo)"
    else
        install -Dm644 "$here/systemd/$unit" "$dst"
        systemctl --user daemon-reload
        fix "$unit installed"
        ensure_user_service "$unit"
    fi
else
    ensure_user_service "$unit"
fi

# 2. ydotool (end-4: virtual keyboard for the on-screen keyboard and widgets)
if user_unit_exists ydotool.service; then
    ensure_user_service ydotool.service
else
    fail "ydotool.service not found (end-4's dependencies are not installed)"
fi

# 3. bluetooth (end-4 enables it; only if the machine has the service)
if systemctl cat bluetooth.service &>/dev/null; then
    if systemctl is-enabled -q bluetooth.service && systemctl is-active -q bluetooth.service; then
        pass "bluetooth.service enabled and running"
    elif $check; then
        fail "bluetooth.service is not enabled/running"
    elif sudo systemctl enable --now bluetooth.service; then
        fix "bluetooth.service enabled and started"
    else
        fail "bluetooth.service could not be started"
    fi
fi

echo
echo "Environment"

# 4. groups end-4 needs for brightness and input devices
missing=()
for g in video input; do
    id -nG | tr ' ' '\n' | grep -qx "$g" || missing+=("$g")
done
if (( ${#missing[@]} == 0 )); then
    pass "user is in the video and input groups"
elif $check; then
    fail "user is not in group(s): ${missing[*]}"
else
    sudo usermod -aG "$(IFS=,; echo "${missing[*]}")" "$USER" && \
        fix "added to group(s) ${missing[*]} (takes effect after logging in again)"
fi

# 5. Python modules for the wallpaper theme generator
if python3 -c 'import numpy, PIL' 2>/dev/null; then
    pass "python3 has numpy and pillow (wallpaper theme generator)"
else
    fail "python3 is missing numpy and/or pillow: sudo pacman -S python-numpy python-pillow"
fi

# 6. ~/.local/bin on PATH (cpmatrix)
if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    pass "~/.local/bin is on PATH (cpmatrix)"
else
    fail "~/.local/bin is not on PATH: run 'fish_add_path ~/.local/bin' in fish"
fi

# 7. btop's wallpaper theme (normally written on every wallpaper change)
generator=$config/matugen/templates/wallpaper-theme/wallpaper-theme.py
source_json=${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/wallpaper-theme/source.json
if [[ -f $config/btop/themes/wallust.theme ]]; then
    pass "btop theme (wallust.theme) exists"
elif $check; then
    fail "btop theme (wallust.theme) has not been generated yet"
elif [[ -f $source_json ]] && "$generator" --no-spicetify --no-icons &>/dev/null; then
    fix "btop theme generated from the current wallpaper"
else
    fail "btop theme not generated yet: pick a wallpaper (Super+Ctrl+T) and it will be"
fi

# 8. Wallpaper icon themes: kde-material-you-colors points KDE/Qt apps at them
icons=${XDG_DATA_HOME:-$HOME/.local/share}/icons
if [[ -d $icons/Wallpaper-dark && -d $icons/Wallpaper-light ]]; then
    pass "Wallpaper-dark/-light icon themes exist"
elif $check; then
    fail "Wallpaper-dark/-light icon themes have not been generated yet"
elif [[ -f $source_json ]] && "$generator" --no-spicetify &>/dev/null; then
    fix "Wallpaper-dark/-light icon themes generated from the current wallpaper"
else
    fail "icon themes not generated yet: pick a wallpaper (Ctrl+Super+T) and they will be"
fi

# 9. Spotify theming through spicetify (optional)
if command -v spicetify &>/dev/null; then
    want=(current_theme Wallpaper color_scheme Wallpaper inject_css 1 inject_theme_js 1
          replace_colors 1 overwrite_assets 1)
    current=$(spicetify config 2>/dev/null)
    need=()
    for ((i = 0; i < ${#want[@]}; i += 2)); do
        grep -qE "^${want[i]}[[:space:]]+${want[i+1]}$" <<<"$current" || need+=("${want[i]}" "${want[i+1]}")
    done
    if (( ${#need[@]} == 0 )); then
        pass "spicetify uses the Wallpaper theme"
    elif $check; then
        fail "spicetify is not set to the Wallpaper theme"
    else
        spicetify config "${need[@]}" &>/dev/null && fix "spicetify set to the Wallpaper theme"
    fi
    spotify_path=$(spicetify config spotify_path 2>/dev/null)
    if [[ -n $spotify_path && ! -w $spotify_path ]]; then
        fail "spicetify cannot write to $spotify_path: sudo chmod a+wr $spotify_path -R  (spicetify's documented fix), then: spicetify backup apply"
    fi
else
    echo "  - spicetify not installed: Spotify keeps its own colours (optional)"
fi

echo
printf 'ok: %d   fixed: %d   problems: %d\n' "$ok" "$fixed" "$bad"
(( bad == 0 ))
