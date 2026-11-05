# Sunshine end-4 Dots

[end-4's illogical-impulse Hyprland dots](https://github.com/end-4/dots-hyprland), with Sunshine's
changes on top: reworked keybinds, no focus stealing by notifications, per-window keyboard layouts,
wallpaper-driven themes for btop, Spotify and icons, transparent terminals, a fastfetch greeting
with your own important dates, and `cpmatrix`.

The original project is installed as end-4 ships it, pinned to commit
[`2f2a376f`](https://github.com/end-4/dots-hyprland/commit/2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8)
(the one the patch is made against), and [`patch/dots-hyprland.patch`](patch/dots-hyprland.patch)
is applied on top before anything is copied into your home.

## Install

On an Arch-based system (Arch, EndeavourOS, Garuda, CachyOS, ...), as your normal user:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tak0dan/Sunshine_end4_Dots/main/install.sh)
```

Use exactly this `bash <(...)` form, not `curl ... | bash`: the installers ask questions and need
your keyboard. Log out and back in when it finishes.

What it does, in order:

1. fetches this repo to `~/.cache/sunshine_end4_dots`
2. puts end-4's dots at the pinned commit in `~/.cache/sunshine_end4_dots-upstream` and applies the patch
3. runs end-4's own installer (`./setup install`): its dependencies, services and config files,
   now including these changes. It offers to back up any config it would overwrite.
4. copies what end-4's installer does not copy: `~/.config/hypr/scripts/` and `cpmatrix`
5. installs the extra packages from [`packages.txt`](packages.txt) (asks about the optional ones)
6. asks for the important dates fastfetch should count (see below)
7. runs [`services.sh`](services.sh), which makes sure every needed service is enabled and running

Running the one-liner again updates everything to the latest version of this repo. Your important
dates are kept.

Options (after the command, e.g. `bash <(curl ...) --skip-packages`):

| option | effect |
|---|---|
| `--skip-end4` | don't run end-4's installer (only the patch and the extras) |
| `--skip-packages` | don't install the extra packages |
| `--skip-dates` | don't ask for important dates |
| `--skip-services` | don't run `services.sh` |
| `-y`, `--yes` | don't ask about optional packages (installs the required ones only) |
| `-- ARGS` | passed to end-4's `./setup install`, e.g. `-- --skip-fish` |

## Changes compared to end-4

### Keybinds

| keys | end-4 | Sunshine |
|---|---|---|
| `Super+Q` | close window | open the terminal |
| `Super+C` | code editor | close window |
| `Super+Shift+C` | colour picker (hyprpicker) | force-kill the focused window |
| `Super+Shift+Alt+Q` | click a window to kill it | force-kill the focused window |
| `Super+B` | left sidebar (`Super+A` / `Super+O` still open it) | browser (`Super+W` too) |
| `Super+Space` | — | toggle tiled/floating (`Super+Alt+Space` still works) |
| `Super+Shift+arrows` | move window | resize window (repeats while held) |
| `Super+Alt+arrows` | — | move window |
| `Super+Shift+number` | — | move window to that workspace and follow it |
| `Ctrl+Super+number` | — | move window to that workspace, stay where you are |
| `Super+Alt+number` | move window to workspace silently | — (use `Ctrl+Super+number`) |
| `Super+number` | go to workspace | same; pressed on the current workspace, goes back to the previous one |
| `Alt+Tab` / `Alt+Shift+Tab` | — | next / previous window on the workspace; a fullscreen or maximized window hands its mode to the next one |
| `Shift+Alt` (hold Shift) | — | switch keyboard layout for the focused window only |
| `Alt+Shift` (hold Alt) | — | switch keyboard layout everywhere |
| `Ctrl+Super+Backslash` | resize to 640×480 (broken in the Lua config) | fixed |

Tapping `Super` alone still opens search. Since Hyprland 0.57 the release of `Super` is reported
even after another key was pressed with it, so in end-4's config every `Super` combination also
opened search. Every bind that uses `Super` now also tells the shell it was a combination, so only
a lone tap opens search.

The top-row number keys are bound by key name only. end-4 also bound them by raw keycode, for
layouts whose number row types other characters (AZERTY, for example). Both binds fired on one
press, which broke the "back to the previous workspace" toggle, so the keycode set was removed.
On such layouts use the numpad, which is still bound.

### Windows and notifications

- **Notifications no longer pull you to another workspace.** end-4 has `focus_on_activate = true`:
  when an app asks for attention (a new Telegram message, a link opened in a browser in the
  background) Hyprland switches to it. This is turned off; the window is marked urgent instead.
  Telegram also gets its own rule, as a safety net for apps that use the X11 activation path.
- **Autostart:** the default terminal running `cpmatrix` on workspace 1 and the default browser on
  workspace 2. "Default" means end-4's `terminal` and `browser` settings (the first installed of
  their lists), or yours from `~/.config/hypr/custom/variables.lua`. They are placed on their
  workspace at startup only; windows opened later go to the current workspace.
- **Keyboard layouts:** `us`, `es`, `ua`. Each window remembers its own layout
  (`Tak0-Per-Window-Switch.py`, running as a systemd user service).
- **The bar's layout indicator** follows a switch at once and always shows the layout of the
  keyboard you type on. end-4's version took the last event from any device, virtual ones
  included, looked each name up with a separate process (dropping quick successive switches),
  and animated every change.
- The active window border is the solid accent colour (end-4: a faint outline).

### Terminals and shell

- **foot** (the default terminal): `Ctrl+C` interrupts (end-4: copy), copy is `Ctrl+Shift+C`,
  paste `Ctrl+Shift+V`. 20% transparent.
- **kitty**: `Ctrl+C` interrupts (end-4: copy or interrupt), copy is `Ctrl+Shift+C`. 40% transparent,
  adjustable. Its config ships with the patch.
- The terminal colour scheme no longer forces an opaque background, so the transparency shows.
- **fish**: runs fastfetch on every new shell, `Ctrl+V` pastes from the clipboard, `~/.local/bin`
  is added to PATH.
- **starship**: the prompt shows the time.

### Wallpaper-driven themes

Regenerated on every wallpaper change (`Ctrl+Super+T`) by
`~/.config/matugen/templates/wallpaper-theme/wallpaper-theme.py`. It samples the wallpaper, groups
its colours into hue families, numbers them, and completes the palette with complementary,
split-complementary, triad and analogous hues on the painter's colour wheel. A green and black
wallpaper also gets rose and ochre. Roles are then assigned with a fixed hierarchy, tone ladder and
chroma budget, calibrated on Material/matugen, so the result stays calm.

- **btop**: `~/.config/btop/themes/wallust.theme`, reloaded in running btop instances. btop also
  gets a transparent background and refreshes every 100 ms (btop's default: 2 s).
- **Spotify** (with spicetify): the "Wallpaper" theme, applied without restarting Spotify.
- **Icons**: Wallpaper-dark and Wallpaper-light, recoloured from Breeze and used by KDE/Qt apps.
- matugen also writes a Material-style `matugen.theme` for btop, which you can pick in btop's options.

### Other

- **Dolphin**: hidden files shown in the folders panel; view and sidebar slightly transparent.
- **fastfetch**: a sun logo and counters for your important dates.
- **cpmatrix** in `~/.local/bin`: a cmatrix-style hex rain with Cyberpunk 2077 hacking windows and
  live system widgets. Run `cpmatrix` (`q` quits, `cpmatrix -h` for options). It needs only Python.

## Important dates

fastfetch shows how long ago each date was, for example:

```
│ ├󰃭 Running Linux (since 2024-03-17)
│ │ └2 years 7 months
│ └󰃭 At my job (since 2025-09-01)
│   └428 days
```

The installer asks for them. Change them any time with:

```bash
~/.cache/sunshine_end4_dots/scripts/set-dates.sh
```

They are stored in `~/.config/fastfetch/custom-info.json`.

## Services

`services.sh` checks, and fixes when needed:

- `tak0-per-window-switch.service` (user): the per-window keyboard layout listener
- `ydotool.service` (user) and `bluetooth.service`, which end-4's shell relies on
- membership of the `video` and `input` groups
- Python's numpy and pillow (theme generator) and `~/.local/bin` on PATH (cpmatrix)
- the generated btop theme and icon themes, and spicetify's settings if spicetify is installed

```bash
~/.cache/sunshine_end4_dots/services.sh --check   # report only
~/.cache/sunshine_end4_dots/services.sh           # report and fix
```

For Spotify theming, spicetify needs write access to Spotify's folder once. That is spicetify's
documented step, so it is left to you: `sudo chmod a+wr /opt/spotify -R && spicetify backup apply`.

## Extra packages

On top of end-4's dependencies (see [`packages.txt`](packages.txt)):

- required: `foot`, `btop`, `fastfetch`, `socat`, `libnotify`, `python-numpy`, `python-pillow`
- optional: `lm_sensors` (btop temperatures), `easyeffects` (end-4 starts it but does not install
  it), and from the AUR `spotify` and `spicetify-cli`

AUR packages are installed with `paru` or `yay` if one of them is installed.

## Updating the patch (maintainers)

Edit the live config, then:

```bash
tools/build-patch.sh
```

It rebuilds `patch/dots-hyprland.patch` from the files listed in `patch/files.txt`, swaps in the
files in `tools/examples/` (personal dates, and the published autostart in
`hypr/hyprland/execs.lua`, so edit that copy for autostart changes), and checks that the patch applies to a clean end-4
checkout and reproduces the live files.

## Uninstall

Use end-4's uninstaller: `cd ~/.cache/sunshine_end4_dots-upstream && ./setup uninstall`. Then
remove the extras: `~/.local/bin/cpmatrix`, `~/.config/hypr/scripts/`, and the user service
(`systemctl --user disable --now tak0-per-window-switch.service`, then delete
`~/.config/systemd/user/tak0-per-window-switch.service`).

## License

GPL-3.0, like end-4's dots this is based on. See [LICENSE](LICENSE). All credit for the original
project goes to [end-4](https://github.com/end-4/dots-hyprland).
