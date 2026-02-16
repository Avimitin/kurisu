{
  self,
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    self.nixosModules.graphic
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf (!config.kurisu.thinkbook13.isInstall) {
    kurisu = {
      graphic = {
        enable = true;
        platform = "intel";
      };
    };

    services.greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --asterisks --remember --remember-session";
          user = "greeter";
        };
      };
    };

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    programs.niri.enable = true;
    programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];
    environment.systemPackages = [
      pkgs.firefox
      pkgs.nautilus
      pkgs.aria2
    ];

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      nerd-fonts.fira-code
    ];

    services.upower.enable = true;
    hardware.bluetooth.enable = true;

    # --- Home Configuration ---
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    # I think I can write a module to unify system and home manager config, with username as arg
    home-manager.users.sh1marin = {
      news.display = "silent";

      home = {
        username = "sh1marin";
        homeDirectory = "/home/sh1marin";
        stateVersion = "25.11";
      };

      imports = [
        self.homeModules.default
        inputs.dms.homeModules.dank-material-shell
      ];

      kurisu.coding-env = {
        enable = true;
        enableLsp = true;
        enableAI = true;
        configureBash = true;
        extraPackages = [
          inputs.nvim.packages.${pkgs.stdenv.hostPlatform.system}.neovim # my neovim
        ];
      };

      kurisu.desktop = {
        enable = true;
      };

      programs.dank-material-shell = {
        enable = true;
        systemd = {
          enable = true;
          restartIfChanged = true;
        };
        # niri = {
        #   enableKeybinds = true;
        #   enableSpawn = true;
        # };
      };

      home.packages = [
        pkgs.ffmpeg
        pkgs.mtr
        pkgs.nexttrace
      ];

      programs.obs-studio.enable = true;
    };
  };
}
