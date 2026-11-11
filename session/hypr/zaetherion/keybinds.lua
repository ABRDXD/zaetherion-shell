local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"
local HOME = os.getenv("HOME")
local hyprScripts = HOME .. "/.config/hypr/scripts"

-- Apps definition
local fileManager = "ski || dolphin || nautilus"
local browser = "zen-browser || firefox"
local codeEditor = "codium || code"
local textEditor = "kate || gnome-text-editor || ski"
local volumeMixer = "pavucontrol-qt || pavucontrol"
local taskManager = "plasma-systemmonitor --page-name Processes || kitty -1 btop"

-- Gesture
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Mouse window manipulation
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind(mainMod .. " + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })

--------------------------------------------------------------------------------
-- Shell & Widgets (Illogical Impulse muscle memory mapped to Serpantinum)
--------------------------------------------------------------------------------
local launcherCmd = "dms ipc call spotlight toggle || pkill fuzzel || fuzzel"
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(launcherCmd), { release = true, description = "Shell: Toggle launcher/search" })
hl.bind("SUPER + SUPER_R", hl.dsp.exec_cmd(launcherCmd), { release = true })
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(launcherCmd), { description = "Shell: Toggle launcher" })

-- Overview / Window switcher
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("rofi -show window || dms ipc call spotlight toggle"), { description = "Shell: Toggle overview / window switcher" })

-- Clipboard history
local clipCmd = "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(clipCmd), { description = "Shell: Toggle clipboard history" })

-- Emoji picker
hl.bind(mainMod .. " + Period", hl.dsp.exec_cmd(hyprScripts .. "/fuzzel-emoji.sh copy"), { description = "Shell: Toggle emoji picker" })

-- Left sidebar / System status
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("dms ipc call control-center toggle"), { description = "Shell: Toggle system controls" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("dms ipc call control-center toggle"), { description = "Shell: Toggle system controls" })
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("dms ipc call control-center toggle"), { description = "Shell: Toggle system controls" })

-- Right sidebar / Calendar & Notifications
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("dms ipc call dash toggle overview"), { description = "Shell: Toggle calendar" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"), { description = "Shell: Toggle notifications" })

-- Media popout
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("dms ipc call dash toggle media"), { description = "Shell: Toggle media controls" })

-- Top bar toggle / autohide
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("dms ipc call bar toggleAutoHide index 0"), { description = "Shell: Toggle top bar autohide" })

-- Wallpaper selector
hl.bind("CTRL + " .. mainMod .. " + T", hl.dsp.exec_cmd("dms ipc call dash toggle wallpaper"), { description = "Shell: Change wallpaper" })

-- Session menu (Power / Lock / Logout)
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("dms ipc call powermenu toggle"), { description = "Shell: Toggle session menu" })

-- Reload shell
hl.bind("CTRL + " .. mainMod .. " + R", hl.dsp.exec_cmd("dms restart"), { description = "Shell: Reload widgets" })
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("dms restart"), { description = "Shell: Reload widgets" })

-- Cheatsheet
hl.bind(mainMod .. " + Slash", hl.dsp.exec_cmd("notify-send 'Keybinds Cheatsheet' 'Super+Q: Close | Super+F: Fullscreen | Super+D: Maximize | Super+V: Clipboard | Super+W: Browser | Super+E: Files | Super+C: Code | Super+Return: Terminal' -a 'Hyprland'"), { description = "Shell: Show keybinds cheatsheet" })

--------------------------------------------------------------------------------
-- Utilities, Screenshots & Screen Recording
--------------------------------------------------------------------------------
-- Screen snip (region)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("dms screenshot"), { description = "Utilities: Screen snip" })

-- Fullscreen screenshot
hl.bind("Print", hl.dsp.exec_cmd("dms screenshot full"), { locked = true, description = "Utilities: Fullscreen screenshot >> clipboard" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd("dms screenshot full"), { locked = true, description = "Utilities: Fullscreen screenshot >> clipboard & file" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("dms screenshot --stdout | satty -f -"), { locked = true, description = "Utilities: Screenshot with editor" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("dms screenshot full"), { locked = true })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("dms screenshot full --stdout | satty -f -"), { locked = true })

-- Color picker
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Pick color #RRGGBB >> clipboard" })

-- Snip to search (Google Lens)
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(hyprScripts .. "/snip_to_search.sh"), { description = "Utilities: Snip to search" })

-- Recording
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("sh -c 'pkill -INT wf-recorder || wf-recorder -g \"$(slurp)\" -f $HOME/Videos/rec-$(date +%Y%m%d-%H%M%S).mp4'"), { locked = true, description = "Utilities: Record region" })
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("sh -c 'pkill -INT wf-recorder || wf-recorder -g \"$(slurp)\" -f $HOME/Videos/rec-$(date +%Y%m%d-%H%M%S).mp4'"), { locked = true })
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd("sh -c 'pkill -INT wf-recorder || wf-recorder  -f $HOME/Videos/rec-$(date +%Y%m%d-%H%M%S).mp4'"), { locked = true, description = "Utilities: Record fullscreen" })
hl.bind(mainMod .. " + SHIFT + ALT + R", hl.dsp.exec_cmd("sh -c 'pkill -INT wf-recorder || wf-recorder --audio -f $HOME/Videos/rec-$(date +%Y%m%d-%H%M%S).mp4'"), { locked = true, description = "Utilities: Record screen with sound" })

--------------------------------------------------------------------------------
-- Screen Zoom
--------------------------------------------------------------------------------
local function zoomfunction(value)
  local zoomvalue = hl.get_config("cursor:zoom_factor") or 1.0
  if (zoomvalue + value) > 3.0 then
    hl.config({ cursor = { zoom_factor = 3.0 } })
  elseif (zoomvalue + value) < 1.0 then
    hl.config({ cursor = { zoom_factor = 1.0 } })
  else
    hl.config({ cursor = { zoom_factor = zoomvalue + value } })
  end
end

hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind(mainMod .. " + Equal", function() zoomfunction(0.3) end, { repeating = true, description = "Screen: Zoom in" })
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

--------------------------------------------------------------------------------
-- Media, Audio & Brightness Controls
--------------------------------------------------------------------------------
-- Brightness
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 5 ''"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment 5 ''"), { locked = true, repeating = true })

-- Volume
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement 5"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment 5"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"), { locked = true })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("dms ipc call audio mute"), { locked = true, description = "Media: Toggle mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("dms ipc call audio micmute"), { locked = true })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio micmute"), { locked = true })
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd("dms ipc call audio micmute"), { locked = true, description = "Media: Toggle mic" })

-- Playback
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play/pause" })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: Previous track" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Media: Next track" })

--------------------------------------------------------------------------------
-- Window Management
--------------------------------------------------------------------------------
-- Focus in direction
local dirs = {
  { key = "Left", dir = "left", d = "l" },
  { key = "Right", dir = "right", d = "r" },
  { key = "Up", dir = "up", d = "u" },
  { key = "Down", dir = "down", d = "d" },
}

for _, item in ipairs(dirs) do
  -- Focus: SUPER + Arrow
  hl.bind(mainMod .. " + " .. item.key, hl.dsp.focus({ direction = item.dir }), { description = "Window: Focus " .. item.key })
  -- Move: SUPER + SHIFT + Arrow
  hl.bind(mainMod .. " + SHIFT + " .. item.key, hl.dsp.window.move({ direction = item.d }), { description = "Window: Move " .. item.key })
end

-- Focus with bracket keys
hl.bind(mainMod .. " + BracketLeft", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + BracketRight", hl.dsp.focus({ direction = "r" }))

-- Resize window: SUPER + CTRL + Up/Down
-- Left/Right resize is off because SUPER + CTRL + Left/Right switches workspaces
-- and repeats when held, which would stretch every window it passes.
-- hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
-- hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

-- Close window
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind(mainMod .. " + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Forcefully zap window" })
hl.bind("ALT + F4", function()
  hl.exec_cmd("notify-send 'Wrong close keybind' 'Super+Q to close. Use Alt+F4 for Windows VMs' -a Hyprland")
end, { non_consuming = true })

-- Split ratio
hl.bind(mainMod .. " + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind(mainMod .. " + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })

-- Positioning modes
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }), { description = "Window: Fullscreen spoof" })
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pin(), { description = "Window: Pin" })
hl.bind("CTRL + " .. mainMod .. " + Backslash", hl.dsp.window.resize({ x = 640, y = 480, "exact" }))

--------------------------------------------------------------------------------
-- Workspaces
--------------------------------------------------------------------------------
-- Switch to workspace 1..10 (SUPER + 1..0)
-- Send window to workspace 1..10 (SUPER + ALT + 1..0 AND SUPER + SHIFT + 1..0)
for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }), { description = "Workspace: Focus " .. ws })
  hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = ws }), { description = "Window: Send to workspace " .. ws })
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

-- Keypad numbers (1..10)
local numpadkeys = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
for i = 1, 10 do
  local ws = tostring(i)
  local code = numpadkeys[i]
  hl.bind(mainMod .. " + code:" .. code, hl.dsp.focus({ workspace = ws }))
  hl.bind(mainMod .. " + ALT + code:" .. code, hl.dsp.window.move({ workspace = ws }))
  hl.bind(mainMod .. " + SHIFT + code:" .. code, hl.dsp.window.move({ workspace = ws }))
end

-- Focus workspace Left / Right
hl.bind("CTRL + " .. mainMod .. " + Left", hl.dsp.focus({ workspace = "r-1" }), { repeating = true, description = "Workspace: Focus left" })
hl.bind("CTRL + " .. mainMod .. " + Right", hl.dsp.focus({ workspace = "r+1" }), { repeating = true, description = "Workspace: Focus right" })
hl.bind(mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("CTRL + " .. mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("CTRL + " .. mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))

-- Send window to workspace Left / Right
hl.bind(mainMod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }), { description = "Window: Send to workspace left" })
hl.bind(mainMod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Window: Send to workspace right" })
hl.bind(mainMod .. " + ALT + Page_Up", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(mainMod .. " + ALT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + Left", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + Right", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + ALT + mouse_up", hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(mainMod .. " + ALT + mouse_down", hl.dsp.window.move({ workspace = "r+1" }))

-- Special Workspace (Scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Toggle scratchpad" })
hl.bind("CTRL + " .. mainMod .. " + S", hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + mouse:275", hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Window: Send to scratchpad" })

--------------------------------------------------------------------------------
-- Applications
--------------------------------------------------------------------------------
-- Terminal
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))

-- File Manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })

-- Browser
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })

-- Code Editor
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })

-- Text Editor
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(textEditor), { description = "App: Text editor" })

-- Settings
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("dms ipc call settings toggle"), { description = "App: Settings" })
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("dms ipc call settings toggle"), { description = "App: Toggle settings" })
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("dms ipc call settings toggle"))

-- Task Manager
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(taskManager), { description = "App: Task manager" })

-- Volume Mixer
hl.bind("CTRL + " .. mainMod .. " + V", hl.dsp.exec_cmd(volumeMixer), { description = "App: Volume mixer" })

-- Network Menu
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("dms ipc call control-center openWith network"), { description = "App: Network" })

--------------------------------------------------------------------------------
-- Session & Power
--------------------------------------------------------------------------------
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("dms ipc call lock lock"), { locked = true })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("dms ipc call lock lock"), { repeating = true, locked = true, description = "Session: Lock screen" })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend"), { locked = true, description = "Session: Suspend" })
hl.bind("CTRL + SHIFT + ALT + " .. mainMod .. " + Delete", hl.dsp.exec_cmd("systemctl poweroff"), { description = "Session: Shut down" })

--------------------------------------------------------------------------------
-- Custom User Keybinds (OLED look & helpers from previous setup)
--------------------------------------------------------------------------------
hl.bind(mainMod .. " + ALT + O", hl.dsp.exec_cmd("env OLED_LOOK_NOTIFY=1 " .. HOME .. "/.local/bin/oled-look toggle"), { description = "Custom: Toggle OLED-inspired display look" })
hl.bind(mainMod .. " + ALT + SHIFT + O", hl.dsp.exec_cmd("env OLED_LOOK_NOTIFY=1 " .. HOME .. "/.local/bin/oled-look next"), { description = "Custom: Cycle five OLED display modes" })
hl.bind("CTRL + " .. mainMod .. " + ALT + Slash", hl.dsp.exec_cmd("xdg-open " .. HOME .. "/.config/hypr/config/keybinds.lua"), { description = "Custom: Edit user keybinds" })

--------------------------------------------------------------------------------
-- Virtual Machine Submap
--------------------------------------------------------------------------------
hl.define_submap("virtual-machine", function()
  hl.bind(mainMod .. " + ALT + F1", function()
    local currentsubmap = hl.get_current_submap()
    if currentsubmap == "virtual-machine" then
      hl.dispatch(hl.dsp.exec_cmd("notify-send 'Exited Virtual Machine submap' 'Keybinds re-enabled' -a 'Hyprland'"))
      hl.dispatch(hl.dsp.submap("reset"))
    elseif currentsubmap == "" then
      hl.dispatch(hl.dsp.exec_cmd("notify-send 'Entered Virtual Machine submap' 'Keybinds disabled. hit SUPER+ALT+F1 to escape' -a 'Hyprland'"))
      hl.dispatch(hl.dsp.submap("virtual-machine"))
    end
  end, { submap_universal = true })
end)
