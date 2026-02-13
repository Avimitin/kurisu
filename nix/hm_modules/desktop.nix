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
  imports = [ ];

  options.kurisu.desktop = {
    enable = mkEnableOption "Configured the Desktop env";
  };

  config = mkIf cfg.enable {
    xdg.dataFile = {
      theme = {
        source = "${../../dotfile/fcitx/theme}";
        target = "fcitx5/themes/default";
      };
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

    services.flameshot = {
      enable = true;
      settings = {
        General = {
          useGrimAdapter = true;
          disabledGrimWarning = true;
          savePath = "${config.home.homeDirectory}/Pictures/Screenshots";
        };
      };
    };

    programs.foot = {
      enable = true;
      server.enable = true;
    };
    xdg.configFile."foot/foot.ini" = ln "foot/foot.ini";

    xdg.configFile = {
      #fontconfig = ln "fontconfig/conf.d";
      #alacritty = ln "alacritty/alacritty.toml";
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
      swaybg = ln "systemd/user/swaybg@.service";
      xdgPortal = ln "xdg-desktop-portal";
    };
  };
}
