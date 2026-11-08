-- Keep only your personal keybinding overrides here. Add new bindings with
-- o.bind or replace defaults with o.rebind.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding. o.rebind takes the same arguments as o.bind.
-- This example replaces the default file manager with Flea.
-- o.rebind("SUPER + SHIFT + F", "File manager", { launch = "flea" })

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { panel = "omarchy.emojis" })

-- Run now (~/Develop/oma-malleations, ~/.local/bin/omarun): the Windows+R box.
-- omarun summons the Omarchy menu's input mode, runs what you type detached,
-- and gets out of the way. Pressing the key again while the box is open closes
-- it. Neither key was bound before: SUPER + CTRL + R and SUPER + CTRL + ALT + R
-- are the reminder bindings, and they are untouched.
o.bind("SUPER + R", "Run now", "omarun")
o.bind("SUPER + SHIFT + R", "Run again", "omarun --history")
