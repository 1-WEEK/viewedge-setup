# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A configuration and script collection for controlling a YXStar YX Display (1200x1080) connected to a Raspberry Pi 4B running Raspberry Pi OS Bookworm with Wayland (labwc compositor). After a system reinstall, run:

```bash
bash ~/Documents/viewedge-setup/setup.sh
```

## Daily Usage

```bash
display-off   # cut USB power to display driver board
display-on    # restore USB power — driver board auto-reinits and redetects HDMI
```

Both commands work over SSH without a password prompt.

## Key Design Decisions

### Why USB power control instead of DPMS or wlr-randr

- `wlopm --on` has a known bug in labwc — cannot reliably wake the display
- `wlr-randr --off` disables the output entirely; on re-enable, resolution is wrong and may trigger the lock screen
- The display driver board is USB-powered, so cutting USB supply (`uhubctl -l 1-1 -a off` + `uhubctl -l 2 -a off`) fully powers it off; on restore the board reinitializes and redetects HDMI cleanly

Pi 4B note: all 4 USB ports are ganged — both hub addresses (`1-1` and `2`) must be toggled together; targeting individual ports only disconnects data, not power.

### Why kanshi `--custom` mode instead of cmdline.txt or wlr-randr

The display's EDID is unreliable (usually reads as empty), so the system defaults to 1920x1080@60Hz. The correct mode is 1200x1080@89.973Hz (exact rate obtained from a one-time successful EDID read).

- `video=HDMI-A-1:1200x1080MR@90` in cmdline.txt: vc4-hdmi's `mode_valid` rejects the CVT-RB timing at the KMS layer — causes black screen on cold boot
- `wlr-randr`: requires the target mode to exist in the EDID mode list, which it usually doesn't
- `kanshi --custom`: bypasses the EDID list entirely; vc4-hdmi accepts the timing at the KMS level; kanshi is event-driven so it applies the mode whenever HDMI-A-1 is connected

kanshi config lives at `~/.config/kanshi/config` (copied from `kanshi-config` by setup.sh). To reload without rebooting: `pkill -HUP -x kanshi`.

### labwc autostart warning

Do **not** place wlr-randr or display commands in `~/.config/labwc/autostart`. When a user-level autostart file exists, labwc replaces the system-level one entirely — this prevents kanshi, panel, and other system services from starting. kanshi is already launched via `/etc/xdg/labwc/autostart`.
