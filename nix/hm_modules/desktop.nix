{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.kurisu.desktop;
  myLib = import ../myLib.nix { inherit config; };
  ln = myLib.fromDotfile;
in
{
  imports = [
    ./fcitx5.nix
    ./terminal
  ];

  options.kurisu.desktop = {
    enable = mkEnableOption "Configured the Desktop env";
  };

  config = mkIf cfg.enable {
    kurisu.fcitx5 = {
      enable = true;
      themesDir = ../../dotfile/fcitx5/themes;
      extraRimeData = [
        ../../dotfile/fcitx5/rime
      ];
    };

    kurisu.terminal = {
      enable = true;
      type = "foot";
      foot.enableServer = true;
    };

    # Application Launcher
    programs.vicinae = {
      enable = true;
      systemd.enable = true;
    };
    xdg.configFile.vicinae-config = ln "vicinae/settings.json";

    programs.mpv.enable = true;
    xdg.configFile.mpv = {
      source = pkgs.runCommand "canonize-uosc-mpv-output" { } ''
        mkdir -p $out/fonts $out/scripts

        cp -r ${pkgs.mpvScripts.uosc}/share/fonts/* $out/fonts/
        cp -r ${pkgs.mpvScripts.uosc}/share/mpv/scripts/* $out/scripts/
        cp -r ${pkgs.mpvScripts.thumbfast}/share/mpv/scripts/* $out/scripts/
        cp ${../../dotfile/mpv/mpv.conf} $out/mpv.conf
      '';
      target = "mpv";
    };

    xdg.configFile.niri = ln "niri/config.kdl";

    xdg.configFile = {
      #fontconfig = ln "fontconfig/conf.d";
      #mangohud = ln "MangoHud/MangoHud.conf";
      mimeapps = ln "mimeapps.list";
      "gtk-3.0" = ln "gtk-3.0";
      "gtk-4.0" = ln "gtk-4.0";
      hyprlock = {
        source = pkgs.replaceVarsWith {
          name = "hyprlock.conf";
          src = ../../dotfile/hypr/hyprlock.conf;

          replacements = {
            backgroundImage = "${config.home.homeDirectory}/Pictures/Wallpapers/hyprlock.jpg";
          };
        };
        target = "hypr/hyprlock.conf";
      };

      zathurarc = ln "zathura/zathurarc";
      xdgPortal = ln "xdg-desktop-portal";
    };
  };
}
