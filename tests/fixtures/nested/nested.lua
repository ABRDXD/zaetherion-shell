-- Minimal nested Hyprland for ZÆTHERION tests (Z109): no autostart, no user binds.
-- tools/nested_hypr.py adds a headless output "ZTEST" that renders even while the
-- nested window sits hidden on a special workspace of the real session.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, allow_session_lock_restore = true } })
