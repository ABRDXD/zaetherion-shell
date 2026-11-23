-- ZÆTHERION: Super+` opens the command line; hold 600 ms to ignite (ZÆTHERION's own core, not FART-next).
local z = os.getenv("HOME") .. "/src/zaetherion-shell/zaetherion"
hl.bind("SUPER + grave", hl.dsp.exec_cmd(z .. " key down"), { description = "ZÆTHERION: command line (hold to ignite)" })
hl.bind("SUPER + grave", hl.dsp.exec_cmd(z .. " key up"), { release = true })
-- Super+Shift+I: keyboard to the island (Z148); with FART open, FART stays open and Esc hands the keyboard back.
hl.bind("SUPER + SHIFT + I", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/src/zaetherion-shell/shell.qml ipc call island focus"), { description = "ZÆTHERION: focus the island" })
