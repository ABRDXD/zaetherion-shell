-- ZÆTHERION: Super+` opens the command line; hold 600 ms to ignite (ZÆTHERION's own core, not FART-next).
local z = os.getenv("HOME") .. "/src/zaetherion-shell/zaetherion"
hl.bind("SUPER + grave", hl.dsp.exec_cmd(z .. " key down"), { description = "ZÆTHERION: command line (hold to ignite)" })
hl.bind("SUPER + grave", hl.dsp.exec_cmd(z .. " key up"), { release = true })
