# Panasonic CF-RZ4 / Sony BVM-9045D

Build target: `nixosConfigurations.cf-rz4`. This is a small standalone host
configuration with SSH, NetworkManager, Xorg, LightDM and XFCE. It does not import
the ThinkBook's Wayland desktop, ZFS layout or Home Manager configuration.
Chromium and mpv are installed system-wide.

Hardware inspected over SSH at `172.24.5.224`: Core M-5Y70, Intel HD 5300 (`i915`),
16 GiB RAM, Samsung 128 GB SATA SSD, UEFI, Intel I218-LM Ethernet and 7265 Wi-Fi.
The fresh-install layout is a 1 GiB EFI partition and ext4 root, with zram swap.
Lid closure and idle time do not suspend the server.
Boot output is quiet, and LightDM automatically signs in as `sh1marin` to XFCE.
System logs remain available with `journalctl -b`; the kernel still prints
errors. To restore the login screen, set `services.displayManager.autoLogin.enable`
to `false`. Console logins and SSH still use their configured authentication.

## Install

The disk configuration names the internal SSD by its inspected hardware ID.
**The disko command below erases that SSD, including Arch and its data.**

1. Boot a NixOS installer in UEFI mode. Use the laptop LCD or SSH for installation;
   the CRT configuration takes effect only when the installed Xorg starts.
2. Copy this repository, including these new files, to the installer and enter it.
   For a Git checkout, add the new host files to Git's index before using the
   flake (Nix ignores untracked files in Git flakes):

   ```sh
   git add machines/nixos/default.nix machines/nixos/cf-rz4
   ```

3. Review `authorized_keys`, which contains the existing authorized public keys
   and the deployment workstation's key. Check that the disk ID in `disk-config.nix` still identifies
   the intended SSD with `lsblk -o NAME,SIZE,MODEL` and `ls -l /dev/disk/by-id/`.
4. Partition, format and mount using the disko version pinned in this flake:

   ```sh
   sudo nix --extra-experimental-features 'nix-command flakes' build \
     .#nixosConfigurations.cf-rz4.config.system.build.diskoScript \
     --out-link /tmp/cf-rz4-disko
   sudo /tmp/cf-rz4-disko
   ```

   Before installation, provision `/mnt/var/lib/cf-rz4/sh1marin-password` and
   `/mnt/var/lib/cf-rz4/root-password` with crypt-format password hashes, owned by
   root with mode 0600 (parent directory 0700). Then run:

   ```sh
   sudo nixos-install --flake .#cf-rz4 --no-root-passwd
   ```

   The migration uses the existing Arch hashes through `nixos-anywhere --extra-files`.
   These files stay outside Git and the Nix store. Password authentication uses
   the existing user password; passwordless sudo for `sh1marin` is retained from Arch. Remote root
   login is disabled. To change a password declaratively, update its hash file.
   Disko supplies the filesystem mounts, so a generated hardware configuration
   must not be imported on top of it with conflicting filesystem entries.
5. Reboot into NixOS. Wired networking uses DHCP. To retain `172.24.5.224`, reserve
   it on the router for Ethernet MAC `20:c6:eb:0d:73:a1`; the configuration does not
   assume that the old lease is permanent. The remote migration preserves the
   existing NetworkManager profiles and machine ID through `--extra-files`.

Later updates use `sudo nixos-rebuild switch --flake .#cf-rz4` from this repository.
Keep `system.stateVersion` at its install value when updating nixpkgs.

For remote installation, use the pinned installer tested for this migration:

```sh
nix run github:nix-community/nixos-anywhere/b6be7b277b468d55082584441cbef1fed8530eb3 -- \
  --flake .#cf-rz4 --target-host sh1marin@172.24.5.224 \
  --copy-host-keys --extra-files /path/to/private/extra-files
```

`extra-files` is a private directory laid out relative to `/`: it contains the
two password hash files, `/etc/NetworkManager/system-connections/`, and
`/etc/machine-id`. Its **directory modes are copied too**: use 0755 for `etc`,
`etc/NetworkManager`, `var` and `var/lib`; 0700 for `var/lib/cf-rz4` and
`etc/NetworkManager/system-connections`; 0600 for the password hashes and
connection files; and 0444 for `etc/machine-id`. Making `/etc` or `/var`
root-only prevents services such as D-Bus from starting.

No general data backup is part of this migration. Subsequent
live updates use `nixos-rebuild`, not the disk-reinstalling `nixos-anywhere`:

```sh
nixos-rebuild switch --flake .#cf-rz4 \
  --target-host sh1marin@172.24.5.224 --sudo
```

`sh1marin` is a trusted Nix user as well as a sudo administrator, so remote
rebuilds can transfer locally built system closures. Builds run on the
deployment workstation unless `--build-host` is also specified.

## CRT output

`display.nix` uses the timing from `/home/sh1marin/screen.sh` on Arch with one
correction: the vertical total is **525**, rather than 526. The mode is named
`bvm-480i-525`:

```text
Modeline "bvm-480i-525" 12.60 640 680 744 800 480 486 492 525 interlace -hsync -vsync
```

This is 15.750 kHz horizontal sync, 60 fields/s and 30 complete frames/s.
It remains a custom timing, not exact 59.94 Hz NTSC. In a live comparison on
2026-10-12, changing only the vertical total made stationary text visibly
sharper according to the user. Fonts, resolution, pixel clock, sync pulses and
polarity were unchanged during the comparison. This implicates the original
timing in the artifact; the precise analog cause was not measured.

The active Arch driver is `xf86-video-intel` (SNA), so NixOS uses `intel` too.
The pinned Intel driver needs Xorg's `int10`, `vgahw` and `shadowfb` modules
preloaded; without these it fails at startup with unresolved symbols such as
`vbeFree` and `vgaHWProtect`. The configuration explicitly loads all three.
The VGA bridge appears as **DP1**, not VGA1. The modeline and sync limits are
attached specifically to DP1 using Xorg's `Monitor-DP1` binding and
`PreferredMode`; they do not constrain the internal LCD.
See the [Xorg monitor configuration reference](https://www.x.org/releases/X11R7.5/doc/man/man5/xorg.conf.5.html).

The CRT becomes primary at native 640×480 with no scaling, rotation or panning.
The LCD is disabled only after the CRT modeset succeeds, and is enabled at its
native resolution when the CRT is absent or the modeset fails. This is applied
before the LightDM greeter and again at login. It configures Xorg, not firmware,
the bootloader or Linux text consoles.

From a terminal inside the graphical session:

```sh
xrandr --verbose          # DP1 should show bvm-480i-525, Interlace, 15.75 kHz
bvm-output                # reapply the layout, including after reconnecting
xrandr --output DP1 --off --output eDP1 --auto --primary  # LCD-only recovery
```

Do not use `xrandr --output DP1 --auto`: the bridge currently advertises ordinary
640×480 **progressive** at 31.47 kHz, which is a different signal. A generic
`cvt 640 480 60` modeline is also not the required 15 kHz television timing.

XFCE defaults disable automatic display profiles and hotplug layout changes;
run `bvm-output` after reconnecting the CRT. If restoring an old home directory,
move aside `~/.config/xfce4/xfconf/xfce-perchannel-xml/displays.xml` while logged
out so a saved XFCE layout does not override Xorg. The font and window-manager
settings are also defaults: existing user preferences take precedence.

## Text stability

The 525-line timing correction above produced a user-confirmed improvement.
Fine horizontal strokes in 480i still alternate between fields, so text can
shimmer even when synchronization is correct. At these timings, an individual
scanline is refreshed about 30 times per second. Software settings cannot make
that behave like a 480-line progressive display at 60 Hz.

The configuration uses 14 pt bold fonts, grayscale antialiasing, slight
hinting, fixed 96 DPI and 1× scaling. LCD subpixel rendering is disabled, as
[Xfce documents that subpixel order is intended for flat panels](https://docs.xfce.org/xfce/xfce4-settings/appearance).
The compositor is disabled to reduce overhead; this is not a cure for interlace
flicker. The terminal defaults to 50×16 characters to fit the small desktop.
Some application dialogs still exceed 640×480; Alt-drag can move them.

These are readability mitigations, not a verified visual fix. Try 16 pt bold if
the remaining desktop space is acceptable. Avoid thin fonts and single-pixel
horizontal patterns. A vertical low-pass filter can reduce interline flicker,
but necessarily softens text, so no extra blur filter is enabled by default.

If whole lines move sideways, the image rolls, or there are doubled edges, that
needs a separate check of the sync conversion, cable and BVM termination; the
current SSH inspection cannot establish the analog signal quality. A separately
tested 240p mode could avoid alternating fields at the cost of half the vertical
workspace, but no unverified 240p timing is enabled here.
