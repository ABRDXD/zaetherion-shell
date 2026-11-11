-- ZÆTHERION session only. Serpantinum, its idle helper and the cliphist watchers do not start here (RISKS.md).
hl.config({ misc = { allow_session_lock_restore = true } })
hl.on("hyprland.start", function()
  hl.exec_cmd(os.getenv("HOME") .. "/src/zaetherion-shell/tools/session-start")
end)
