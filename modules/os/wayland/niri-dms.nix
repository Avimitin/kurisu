{
  lib,
  myLibBuilder,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.kurisu.os.wayland;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  options.kurisu.os.wayland.niri-dms = { };

  config = lib.mkIf (cfg.enable && cfg.desktop == "niri-dms") {
    # --- NixOS configurations --- #
    programs.niri.enable = true;

    # Web browser and file browser
    environment.systemPackages = [
      pkgs.firefox
      pkgs.nautilus
    ];

    # Fix GTK icons
    programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Battery component
    services.upower.enable = true;

    # Headphone
    hardware.bluetooth.enable = true;

    # --- Home Configurations --- #
    home-manager.sharedModules = [
      inputs.dms.homeModules.dank-material-shell
    ];

    home-manager.users = lib.mkIf (cfg.user != null) {
      "${cfg.user}" =
        let
          myLib = myLibBuilder { config = config.home-manager.users."${cfg.user}"; };
        in
        {
          # Configuration for niri
          xdg.configFile.niri = myLib.fromDotfile "niri/config.kdl";

          # Dank shell for locker, settings
          programs.dank-material-shell = {
            enable = true;
            systemd = {
              enable = true;
              restartIfChanged = true;
            };
          };
          # Enable the kdeconnect plugin
          xdg.configFile."DankMaterialShell/plugins/DankKDEConnect".source =
            "${pkgs.dms-plugins}/DankKDEConnect";

          # Application Launcher
          programs.vicinae = {
            enable = true;
            systemd.enable = true;
          };
          xdg.configFile.vicinae-config = myLib.fromDotfile "vicinae/settings.json";

          # TODO: MPV should be in one directory
          programs.mpv.enable = true;
          xdg.configFile.mpv = {
            source = pkgs.runCommand "canonize-uosc-mpv-output" { } ''
              mkdir -p $out/fonts $out/scripts

              cp -r ${pkgs.mpvScripts.uosc}/share/fonts/* $out/fonts/
              cp -r ${pkgs.mpvScripts.uosc}/share/mpv/scripts/* $out/scripts/
              cp -r ${pkgs.mpvScripts.thumbfast}/share/mpv/scripts/* $out/scripts/
              cp ${../../../dotfile/mpv/mpv.conf} $out/mpv.conf
            '';
            target = "mpv";
          };

          xdg.configFile = {
            mimeapps = myLib.fromDotfile "mimeapps.list";
            xdgPortal = myLib.fromDotfile "xdg-desktop-portal";
          };

          # Home connection
          services.kdeconnect.enable = true;
        };
    };
  };
}
