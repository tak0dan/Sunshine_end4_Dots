-- put former exec-once commands inside the func and former exec commands outside

-- The default apps (terminal, browser) from variables.lua, or the user's
-- overrides in custom/variables.lua
require("hyprland.lib")
require("hyprland.variables")
if is_file_exists(HOME .. "/.config/hypr/custom/variables.lua") then
    require("custom.variables")
end

local function on_path(bin)
    for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
        local f = io.open(dir .. "/" .. bin, "r")
        if f then
            f:close()
            return true
        end
    end
    return false
end

-- The first installed app of a launch_first_available list ('foot' 'kitty -1'
-- ...), or the value itself if it is a plain command (custom override).
-- Startup apps are started directly, not through launch_first_available.sh:
-- that script detaches the app and exits, so Hyprland could not tie the
-- window to the workspace it was started for.
local function first_available(list)
    local found = false
    for cand in list:gmatch("'([^']*)'") do
        found = true
        if on_path(cand:match("^(%S+)")) then
            return cand
        end
    end
    return not found and list or nil
end

-- A terminal command running `cmd`, in the form that terminal expects
local exec_flag = { alacritty = "-e", konsole = "-e", kgx = "-e", xterm = "-e", uxterm = "-e",
                    wezterm = "start --" }
local function running(term, cmd)
    local flag = exec_flag[term:match("^(%S+)")]
    return term .. " " .. (flag and (flag .. " ") or "") .. cmd
end

hl.on("hyprland.start", function ()

    -- Bar, wallpaper
    hl.exec_cmd("$HOME/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
    hl.exec_cmd("qs -c $qsConfig")
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Startup apps: the default terminal running cpmatrix on workspace 1 and
    -- the default browser on workspace 2. Each is placed on its workspace at
    -- launch only, so windows opened later go to the current workspace.
    local term, web = first_available(terminal), first_available(browser)
    if term then
        hl.exec_cmd(running(term, "$HOME/.local/bin/cpmatrix"), { workspace = 1 })
    end
    if web then
        hl.exec_cmd(web, { workspace = 2 })
    end

    -- Core components (authentication, lock screen, notification daemon)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

    -- Audio
    hl.exec_cmd("easyeffects --hide-window --service-mode")

    -- Clipboard: history
    --hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
