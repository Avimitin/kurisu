# Kurisu
![heading.jpg](./index.jpg)

This is my NixOS configuration, named by Makise Kurisu.

## Usage
Configure Nix with experimental features "flakes" and "nix-command", then run:

```bash
nix run '.#nh' -- os switch .
```

## Modules

### NixOS Modules

#### `kurisu.basic-env`
- `enable` (bool): Minimal Wayland Environment.

#### `kurisu.openvpn`
- `enable` (bool): Create a OpenVPN instance.
- `servers` (attrs): Configuration for OpenVPN servers.

### Home Manager Modules

#### `kurisu.coding-env`
- `enable` (bool): Configured home as coding env.
- `enableLsp` (bool): Install common used LSP server.
- `enableAI` (bool): Install common used AI stuff.
- `configureBash` (bool): Configure bash.
- `extraPackages` (list of package): Additional packages to install.

#### `kurisu.desktop`
- `enable` (bool): Configured the Desktop env.

#### `kurisu.fcitx5`
- `enable` (bool): Enable Fcitx5 with rime.
- `themesDir` (path, nullable): Path to theme directory.
- `rimeData` (list of package): List of rime scheme/dictionary to set in user data directory.
- `extraRimeData` (list of path): List of directory to append into user data directory.

#### `kurisu.terminal`
- `enable` (bool): Enable Terminal customization.
- `type` (enum: `foot`, `alacritty`, `ghostty`, nullable): Select an terminal option to enable.
- `foot.settingsPath` (path): Path to foot config file.
- `foot.enableServer` (bool): Enable systemd foot terminal server service.
- `alacritty.settingsPath` (path): Path to alacritty config file.
- `ghostty.settingsPath` (path): Path to ghostty config file.

#### `kurisu.unixporn`
- `enable` (bool): Do ricing.
- `style` (enum: `whitesur`, nullable): Select a style to enable.