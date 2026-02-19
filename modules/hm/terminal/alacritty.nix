{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.hm.terminal;
in
{
  imports = [ ];

  options.kurisu.hm.terminal.alacritty = {
    settingsPath = lib.mkOption {
      type = lib.types.path;
      default = ../../../dotfile/alacritty/alacritty.toml;
      description = "path to config, default to dotfile/alacritty/alacritty.toml";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.type == "alacritty") {
    kurisu.hm.terminal.package = pkgs.alacritty;
    xdg.configFile."alacritty/alacritty.toml".source = cfg.alacritty.settingsPath;
  };
}
