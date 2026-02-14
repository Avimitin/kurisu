{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.unixporn;
in
{
  imports = [ ];

  # TODO: support dark/light variant? But I don't need too much skins
  options.kurisu.unixporn.whitesur = { };

  config = lib.mkIf (cfg.enable && cfg.style == "whitesur") {
    kurisu.unixporn.gtk_settings = {
      enable = true;
      theme = {
        name = "WhiteSur-Dark";
        package = pkgs.whitesur-gtk-theme;
      };
      iconTheme = {
        name = "WhiteSur-dark";
        package = pkgs.whitesur-icon-theme;
      };
      cursorTheme = {
        name = "WhiteSur-cursors";
        package = pkgs.whitesur-cursors;
      };
    };

    kurisu.unixporn.qt_settings = {
      enable = true;
      platformTheme.name = "qtct";
      style = {
        name = "kvantum";
      };
    };

    xdg.configFile = {
      "Kvantum/kvantum.kvconfig".source = (pkgs.formats.ini { }).generate "kvantum.kvconfig" {
        General.theme = "WhiteSurDark";
      };
      "Kvantum/WhiteSur".source = "${pkgs.whitesur-kde}/share/Kvantum/WhiteSur";
    };
  };
}
