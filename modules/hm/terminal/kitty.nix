{
  lib,
  config,
  ...
}:
let
  cfg = config.kurisu.hm.terminal;
in
{
  imports = [ ];

  options.kurisu.hm.terminal.kitty = {
    settingsPath = lib.mkOption {
      type = lib.types.path;
      default = ../../../dotfile/kitty/kitty.conf;
      description = "path to config, default to dotfile/kitty/kitty.conf";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.type == "kitty") {
    xdg.configFile."kitty/kitty.conf".source = cfg.kitty.settingsPath;
  };
}
