# Changelog

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
  with a Conky version gate (patched AppImage offered when needed), select
  theme and sidebar position, install fonts, configure the desktop layer
  and multi-monitor setups, build dynamic core rows, and set up autostart,
  start-now, and uninstall.