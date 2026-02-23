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
    enable = mkEnableOption "Enable Fcitx5 with rime";

    themesDir = mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to theme directory";
    };

    rimeData = mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        rime-data # Do I really need default rime scheme?
        rime-dict
        rime-moegirl
      ];
      example = [ ];
      description = "List of rime scheme/dictionary to set in user data directory. Use `lib.mkForce` to override the list.";
    };

    extraRimeData = mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = [ ];
      description = "List of directory to append into user data directory.";
    };
  };

  config = mkIf cfg.enable {
    i18n.inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5 = {
        addons = with pkgs; [
          fcitx5-rime # Rime
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
        fcitx5-conf = ln "conf";
        fcitx5-config = ln "config";
        fcitx5-profile = ln "profile";
      };

    xdg.dataFile.kurisu-no-rime-data =
      let
        groupped = pkgs.symlinkJoin {
          name = "kurisu-no-rime-data";
          paths = cfg.rimeData;
          postBuild = lib.optionalString (cfg.extraRimeData != [ ]) (
            lib.concatStringsSep "\n" (
              map (p: "${pkgs.lndir}/bin/lndir -silent ${p} $out/share/rime-data") cfg.extraRimeData
            )
          );
        };
      in
      {
        recursive = true;
        source = "${groupped}/share/rime-data";
        target = "fcitx5/rime";
      };

    xdg.dataFile.kurisu-fcitx5-themes = mkIf (cfg.themesDir != null) {
      source = "${cfg.themesDir}";
      target = "fcitx5/themes";
    };
  };
}
