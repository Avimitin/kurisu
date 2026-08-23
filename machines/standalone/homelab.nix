{
  lib,
  pkgs,
  self,
  config,
  ...
}:
let
  myLib = import ../../nix/myLib.nix { inherit config; };
in
{
  imports = [
    self.homeModules.unixporn
    self.homeModules.tools
    self.homeModules.fcitx5
    self.homeModules.fontconfig
    self.homeModules.home-assistant
    self.homeModules.terminal
    self.homeModules.zed
  ];

  options = {
    home.packages = lib.mkOption {
      apply =
        let
          blacklist = [
            "qt5ct"
            "qt6ct"
            "qtstyleplugin-kvantum"
            "fcitx5"
            "zed-editor"
          ];
        in
        with builtins;
        pkgs: filter (p: p != null && !(elem (lib.getName p) blacklist)) pkgs;
    };
  };

  config = {
    news.display = "silent";

    nixpkgs.config.allowUnfree = true;

    nix.package = pkgs.nix;
    # Simply run nix run k#hello to run temporary programs
    nix.registry.k.to = {
      type = "path";
      path = "${config.home.homeDirectory}/kurisu";
    };

    home = {
      username = "sh1marin";
      homeDirectory = "/home/sh1marin";
      stateVersion = "26.05";
    };

    kurisu.hm.zed.enable = true;

    kurisu.hm.unixporn = {
      enable = true;
      style = "whitesur";
    };

    kurisu.hm.fcitx5 = {
      enable = true;
      themesDir = ../../dotfile/fcitx5/themes;
      extraRimeData = [
        ../../dotfile/fcitx5/rime
      ];
    };

    kurisu.hm.terminal = {
      enable = true;
      type = "foot";
    };

    kurisu.hm.fontconfig.enable = true;

    kurisu.hm.home-assistant = {
      enable = true;

      # Keep configuration.yaml and UI-created state mutable. The state directory
      # contains plaintext authentication and integration tokens; keep its mode
      # private and include it only in encrypted backups.
      config = null;
      configDir = "${config.xdg.stateHome}/home-assistant";

      # Xiaomi Home's OAuth callback is fixed to http://homeassistant.local:8123.
      # DNS or mDNS for that name and the host firewall are system-level settings
      # and cannot be managed by this standalone Home Manager configuration.
      extraComponents = [
        "default_config"
        "met"
        "esphome"
        "ffmpeg"
        "upnp"
        "zeroconf"
      ];
      customComponents = [
        pkgs.home-assistant-custom-components.xiaomi_home
      ];
    };

    # Configuration for niri
    xdg.configFile.niri = myLib.fromDotfile "niri/config.kdl";

    # Dank shell for locker, settings
    systemd.user.services.dms = {
      Unit = {
        Description = "DankMaterialShell";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };

      Service = {
        # Ensure we are using Arch Linux DMS
        Environment = ''PATH="/bin:/usr/bin"'';
        ExecStart = "/usr/bin/dms run --session";
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    # Enable the kdeconnect plugin
    xdg.configFile."DankMaterialShell/plugins/DankKDEConnect".source =
      "${pkgs.dms-plugins}/DankKDEConnect";

    # Application Launcher
    programs.vicinae = {
      enable = false;
      systemd.enable = false;
    };

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

    xdg.configFile = {
      mimeapps = myLib.fromDotfile "mimeapps.list";
      xdgPortal = myLib.fromDotfile "xdg-desktop-portal";
    };

    home.packages = [
      pkgs.nerd-fonts.fira-code
    ];

    # Home connection
    systemd.user.services.kdeconnect = {
      Unit = {
        Description = "Adds communication between your desktop and your smartphone";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Service = {
        Environment = [ "PATH=/bin:/usr/bin" ];
        ExecStart = "/usr/bin/kdeconnectd";
        Restart = "on-abort";
      };
    };

    kurisu = {
      hm.tools = {
        enable = true;
        enableLsp = true;
        enableAI = true;
        configureBash = true;
        configureFish = true;
      };
    };

    programs.git.settings = {
      user = {
        name = "Avimitin";
        email = "dev@avimit.in";
        signingkey = "~/.ssh/id_ed25519.pub";
      };
    };
  };
}
