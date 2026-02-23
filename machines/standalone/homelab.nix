{
  lib,
  inputs,
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
    self.homeModules.terminal

    inputs.nvim.homeModules.nvim
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

    home = {
      username = "sh1marin";
      homeDirectory = "/home/sh1marin";
      stateVersion = "25.11";
    };

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
      foot.enableServer = true;
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
      enable = true;
      systemd.enable = true;
    };
    xdg.configFile.vicinae-config = myLib.fromDotfile "vicinae/settings.json";

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

    fonts.fontconfig.enable = true;
    home.packages = [
      pkgs.nerd-fonts.fira-code
    ];

    # Home connection
    services.kdeconnect.enable = true;

    kurisu = {
      hm.tools = {
        enable = true;
        enableLsp = true;
        enableAI = true;
        configureBash = true;
      };
    };

    programs.avimitin-nvim = {
      enable = true;
      treesitter-grammars = [
        # builtins
        "bash"
        "cpp"
        "css"
        "comment"
        "diff"
        "gitcommit"
        "typst"
        "llvm"
        "regex"
        "ruby"
        "python"
        "rust"
        "scala"
        "nix"
        "yaml"
        "meson"

        pkgs.tree-sitter-grammars.tree-sitter-lean
      ];
    };
  };
}
