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

  options.kurisu.hm.terminal.ghostty = {
    settingsPath = lib.mkOption {
      type = lib.types.path;
      default = ../../../dotfile/ghostty/config;
      description = "path to config, default to dotfile/ghostty/config";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.type == "ghostty") {
    kurisu.hm.terminal.package = pkgs.ghostty;
    xdg.configFile."ghostty/config".source = cfg.ghostty.settingsPath;
  };
}
