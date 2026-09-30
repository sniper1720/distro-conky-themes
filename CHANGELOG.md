# Changelog

## [1.1.0] - 2026-09-29

### Added

- Use the wlr-layer-shell `desktop` namespace on KDE Wayland: KWin
  classifies Conky as a desktop window there, so Show Desktop (Meta+D)
  no longer hides it.

### Changed

- Install the official upstream Conky AppImage instead of a patched
  build: the SHM buffer guard and the `own_window_namespace` setting
  both shipped in Conky 1.25.0, so the patches are no longer needed.
  The installer now tracks the newest upstream release, so future Conky
  versions arrive without a code change.
- Raise the Conky version gate to 1.25.1: 1.25.0 is the first release
  carrying the settings the themes need, and 1.25.1 fixes a startup
  crash in font setup that hit every launch. An already-installed
  AppImage below the gate counts as absent, so the retired patched
  builds are replaced on reinstall.
- Detect the output backend from the display session: Conky 1.25
  deprecated `out_to_x` and `out_to_wayland` in favor of its own
  session detection.
- Rename `own_window_colour` to `own_window_color` and `xftalpha` to
  `text_alpha`: both old names still work but are deprecated.
- Bump the Pure font sizes by 1pt and widen the bars to the full widget
  width: the sidebar stays legible on displays without DPI scaling.

## [1.0.0] - 2026-08-29

Started in 2016 as a single custom Conky theme for Solus, this project
is now a universal suite featuring the Octopus and Pure themes, both
rebuilt for native X11 and Wayland support on any Linux distribution.

### Added

- Add universal distro support for 10 distributions with official logos
  and brand colors: Solus, Fedora, Arch, Ubuntu, Debian, openSUSE, NixOS,
  Pop!_OS, CachyOS, and Linux Mint.
- Add Octopus, the original Cairo/Lua dashboard with curved arms and
  resolution-adaptive dark and light modes.
- Add Pure, the Xft sidebar with bars, metrics, and dynamic per-core
  CPU detection.
- Support native rendering on both X11 and Wayland: on Wayland the themes
  use `wlr-layer-shell` for correct desktop integration (Sway, Hyprland,
  KDE Plasma); GNOME runs as a normal window unless `mutter-layer-shell`
  is present.
- Ship an all-in-one installer (`setup.sh`): detect the distro from
  `/etc/os-release`, detect the X11/Wayland session, check dependencies
  with a Conky version gate (AppImage offered when needed), select
  theme and sidebar position, install fonts, configure the desktop layer
  and multi-monitor setups, build dynamic core rows, and set up autostart,
  start-now, and uninstall.