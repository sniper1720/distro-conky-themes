-- Distro Conky Themes: Octopus Settings

-- width/height are the usable logical screen size; the installer sets them
-- to the detected display so the widget always fits without a scale factor.
-- The defaults below are only a fallback when screen detection fails; the
-- theme is fully proportional, so any canvas size renders identically.
local settings = {
    width = 1920,
    height = 1080,
    network_interface = "wlan0",
    theme_mode = "DARK",  -- "DARK" or "WHITE"
    mail_dir = "",  -- Maildir path for ${new_mails}; empty hides the Mail arm
    disc_alpha = 0,  -- Hidden gem: translucent ink disc over the logo (0 = off; ~0.4 = sink effect)
}

return settings
