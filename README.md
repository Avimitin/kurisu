# Kurisu
![heading.jpg](./index.jpg)

This is my NixOS configuration, named by Makise Kurisu.

## Overview

This is a comprehensive NixOS and Home Manager configuration project, structured as a Nix Flake using `flake-parts`. It manages both full NixOS system configurations and standalone Home Manager environments.

### Project Structure

*   **`flake.nix`**: The entry point. It defines inputs (nixpkgs, home-manager, etc.) and outputs. It uses `flake-parts` to organize the configuration.
    *   **`nixosConfigurations`**: Defines NixOS machine configurations (imported from `machines/nixos`).
    *   **`homeConfigurations`**: Defines standalone home-manager setups (imported from `machines/standalone`).
    *   **`flake.nixosModules` / `flake.homeModules`**: Exports reusable modules from `modules/`.

### 1. Modules (`modules/`)
The core logic resides here, split into OS-level and Home-level modules. They are exported as attribute sets of paths in `modules/default.nix`.

*   **`modules/os/` (NixOS Modules)**:
    *   Contains system-level configurations like `common-config`, `graphic`, `partitions` (ZFS layouts), `wayland` (desktop environment), and `login_manager`.
    *   **Key Pattern**: These modules often define options under the `kurisu.os` namespace (e.g., `kurisu.os.wayland.enable`).
    *   **Integration**: Some OS modules (like `wayland`) automatically inject corresponding Home Manager modules into the user's configuration via `home-manager.sharedModules`.

*   **`modules/hm/` (Home Manager Modules)**:
    *   Contains user-level configurations like `tools` (shell, neovim), `fcitx5` (input method), `terminal` (foot, ghostty), and `unixporn` (theming).
    *   **Key Pattern**: These define options under the `kurisu.hm` namespace.

### 2. Machines (`machines/`)
This directory defines the actual hosts and how they compose the modules.

*   **`machines/nixos/` (NixOS Hosts)**:
    *   Managed via standard **NixOS configurations**.
    *   **`thinkbook13`**: A specific machine configuration.
        *   **`bare.nix`**: The base system (bootloader, ZFS partitions, networking). Imports `self.nixosModules.common-config`, `partitions`, `ovpn`.
        *   **`desktop.nix`**: The graphical environment. Imports `self.nixosModules.wayland`, `graphic`, `login_manager`. It also configures the user `sh1marin` via the embedded `home-manager` module, importing `self.homeModules.tools`.

*   **`machines/standalone/` (Standalone Home Manager)**:
    *   Managed via standard **Home Manager**.
    *   **`homelab`**: A configuration for a non-NixOS environment (e.g., a server or another distro).

### 3. Support Directories
*   **`dotfile/`**: Contains raw configuration files (e.g., `fish`, `nvim`, `wezterm`, `hypr`). These are symlinked or referenced by the Home Manager modules (e.g., `xdg.configFile."...".source = ./dotfile/...`).
*   **`nix/`**: Contains helper functions (`myLib.nix`), overlays (`overlay.nix`), and custom package definitions (`pkgs/`).

## Usage
Configure Nix with experimental features "flakes" and "nix-command", then run:

```bash
nix run '.#nh' -- os switch .
```

## Modules

### NixOS Modules

#### `kurisu.os.graphic`
- `enable` (bool): Enable video card configuration.
- `platform` (enum: `intel`, nullable): Select one of the platform to configure.

#### `kurisu.os.openvpn`
- `enable` (bool): Create a OpenVPN instance.
- `servers` (attrs): Configuration for OpenVPN servers.

#### `kurisu.partitions`
- `enable` (bool): Enable Disko partition.
- `profile` (enum: `zfs-single-root`, nullable): Select an partition profile.
- `zfs-single-root.diskName` (str): The main disk for zfs to do partition.
- `zfs-single-root.extraDatasets` (attrs): Extra dataset config to disko.

#### `kurisu.os.wayland`
- `enable` (bool): Wayland Desktop Environment.
- `desktop` (enum: `niri-dms`): Select a pre-configured desktop environment.
- `user` (str, nullable): Select a user to apply the biased Niri config.
- `unixpornStyle` (str, nullable): Select a unified unixporn style.
- `enableFcitx5` (bool): Configured Fcitx5.
- `terminal` (attrs): Options to the kurisu.hm.terminal module.

#### `kurisu.os.login_manager`
- `enable` (bool): Login Manager.
- `profile` (enum: `tuigreet`): Profile for login manager.

#### `kurisu.os.canokey`
- `enableRootlessAccess`: Allow rootless access to Canokey.
- `accessGroup`: specify which group users in it can access Canokey.

#### `kurisu.machines.thinkbook13`
- `isInstall` (bool): Enables a minimal NixOS build layer.

### Home Manager Modules

#### `kurisu.hm.tools`
- `enable` (bool): Common sets of tools.
- `enableLsp` (bool): LSP servers.
- `enableAI` (bool): AI editors or CLIs.
- `configureBash` (bool): Bash with configs.
- `configureFish` (bool): Fish with configs.
- `extraPackages` (list of package): Additional packages to install.

#### `kurisu.hm.fcitx5`
- `enable` (bool): Enable Fcitx5 with rime.
- `themesDir` (path, nullable): Path to theme directory.
- `rimeData` (list of package): List of rime scheme/dictionary to set in user data directory.
- `extraRimeData` (list of path): List of directory to append into user data directory.

#### `kurisu.hm.home-assistant`

- `enable` (bool): Run Home Assistant as a hardened systemd user service.
- `configDir` (string): Mutable state directory; defaults to `$XDG_STATE_HOME/home-assistant`.
- `config` (YAML attribute set, nullable): Declarative `configuration.yaml`, or `null` for UI-managed configuration.
- `extraComponents` (list of string): Built-in integrations whose Python dependencies are included.
- `customComponents` (list of package): Custom integrations linked into `custom_components`.
- `extraPackages` (function): Additional Python packages available to Home Assistant.
- `runtimePackages` (list of package): Additional executables available to integrations.
- `writablePaths` (list of string): Additional paths writable through the service sandbox.

This module is a Home Manager adaptation of nixpkgs' NixOS Home Assistant module.
System-level setup such as firewall rules, device permissions, mDNS, and user lingering
must still be configured on the host.

The Windows screen-light automation can be installed from an elevated PowerShell
session with `scripts/install-home-assistant-screen-light.ps1`. It stores the local-only
webhook ID under an ACL-restricted ProgramData directory and starts a heartbeat task in
the selected user's session at logon. Home Assistant should use each heartbeat as a
restartable 90-second lease, so the light turns off after logout, sleep, shutdown, a
crash, or power loss without relying on a final Windows shutdown request.

Configure the existing Home Assistant webhook automation like this, retaining its
private webhook ID and replacing `light.screen_light` with the actual entity ID:

```yaml
alias: Windows screen-light lease
triggers:
  - trigger: webhook
    webhook_id: REPLACE_WITH_THE_EXISTING_PRIVATE_ID
    allowed_methods:
      - POST
    local_only: true
conditions:
  - condition: template
    value_template: "{{ trigger.json.state | default('') in ['on', 'off'] }}"
actions:
  - choose:
      - conditions:
          - condition: template
            value_template: "{{ trigger.json.state == 'on' }}"
        sequence:
          - if:
              - condition: template
                value_template: >-
                  {{ not is_state('light.screen_light', 'on') }}
            then:
              - action: light.turn_on
                target:
                  entity_id: light.screen_light
          - delay: "00:01:30"
          - action: light.turn_off
            target:
              entity_id: light.screen_light
      - conditions:
          - condition: template
            value_template: "{{ trigger.json.state == 'off' }}"
        sequence:
          - action: light.turn_off
            target:
              entity_id: light.screen_light
mode: restart
```

#### `kurisu.hm.terminal`
- `enable` (bool): Enable Terminal customization.
- `type` (enum: `foot`, `alacritty`, `ghostty`, nullable): Select an terminal option to enable.
- `foot.settingsPath` (path): Path to config, default to dotfile/foot/foot.ini.
- `foot.enableServer` (bool): Enable systemd foot terminal server service.
- `alacritty.settingsPath` (path): Path to config, default to dotfile/alacritty/alacritty.toml.
- `ghostty.settingsPath` (path): Path to config, default to dotfile/ghostty/config.

#### `kurisu.hm.unixporn`
- `enable` (bool): Do ricing.
- `style` (enum: `whitesur`, nullable): Select a style to enable.
