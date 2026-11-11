-- ZÆTHERION session only. Serpantinum and its idle helper do not start here (RISKS.md).
-- Clipboard history: cliphist keeps recording (owner's choice, 11 Nov 2026); DMS's own clipboard stays off.
hl.config({ misc = { allow_session_lock_restore = true } })
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd(os.getenv("HOME") .. "/src/zaetherion-shell/tools/session-start")
end)
