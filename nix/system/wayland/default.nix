{
  lib,
  config,
  self,
  ...
}:
let
  cfg = config.kurisu.os.wayland;
in
{
  imports = [ ./niri-dms.nix ];

  options.kurisu.os.wayland = {
    enable = lib.mkEnableOption "Wayland Desktop Environment";

    desktop = lib.mkOption {
      type = lib.types.enum [
        "niri-dms"
      ];
      description = "Select a pre-configured desktop environment";
      example = "niri-dms";
    };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "user1";
      description = "Select a user to apply the biased Niri config";
    };

    unixpornStyle = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "whitesur";
      description = "Select a unified unixporn style";
    };

    enableFcitx5 = lib.mkEnableOption "Configured Fcitx5";

    terminal = lib.mkOption {
      type = lib.types.attrs;
      description = "Options to the kurisu.hm.terminal module";
    };
  };

  config = lib.mkIf (cfg.enable) {
    home-manager.sharedModules = [
      self.homeModules.fcitx5
      self.homeModules.terminal
      self.homeModules.unixporn
    ];

    home-manager.users = lib.mkIf (cfg.user != null) {
      "${cfg.user}" = {
        kurisu.unixporn = {
          enable = cfg.unixpornStyle != null;
          style = cfg.unixpornStyle;
        };

        kurisu.fcitx5 = {
          enable = cfg.enableFcitx5;
          themesDir = ../../../dotfile/fcitx5/themes;
          extraRimeData = [
            ../../../dotfile/fcitx5/rime
          ];
        };

        kurisu.terminal = cfg.terminal;
      };
    };
  };
}
