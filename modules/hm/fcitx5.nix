{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.kurisu.hm.fcitx5;
in
{
  imports = [ ];

  options.kurisu.hm.fcitx5 = {
    enable = mkEnableOption "Enable Fcitx5 with Phono Xiaohe and Mozc";

    themesDir = mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to theme directory";
    };

  };

  config = mkIf cfg.enable {
    i18n.inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5 = {
        addons = with pkgs; [
          phono-fcitx5-addon # Chinese: Phono Xiaohe Shuangpin
          qt6Packages.fcitx5-chinese-addons # Native Chinese punctuation used by Phono
          fcitx5-pinyin-moegirl
          fcitx5-pinyin-zhwiki
          fcitx5-gtk # GTK module
          fcitx5-mozc # Japanese
        ];
        waylandFrontend = true; # Don't set IM_MODULE env... wayland protocol have better impl
      };
    };

    xdg.configFile =
      let
        ln = stem: {
          source = ../../dotfile/fcitx5/${stem};
          target = "fcitx5/${stem}";
        };
      in
      {
        fcitx5-conf = {
          target = "fcitx5/conf";
          source = pkgs.symlinkJoin {
            name = "fcitx5-conf";
            paths = [
              ../../dotfile/fcitx5/conf
              (pkgs.writeTextDir "phono.conf" ''
                Enabled=True
                ModelDirectory=${pkgs.phono-model}
                ShuangpinScheme=Xiaohe
              '')
            ];
          };
        };
        fcitx5-config = ln "config";
        fcitx5-profile = ln "profile";
      };

    xdg.dataFile.kurisu-fcitx5-themes = mkIf (cfg.themesDir != null) {
      source = "${cfg.themesDir}";
      target = "fcitx5/themes";
    };
  };
}
