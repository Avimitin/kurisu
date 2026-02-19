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
    self.nixosModules.wayland
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf (!config.kurisu.thinkbook13.isInstall) {
    kurisu = {
      graphic = {
        enable = true;
        platform = "intel";
      };
      os.wayland = {
        enable = true;
        user = "sh1marin";

        desktop = "niri-dms";

        unixpornStyle = "whitesur";

        enableFcitx5 = true;

        terminal = {
          enable = true;
          type = "foot";
          foot.enableServer = true;
        };
      };
    };

    # Greeter should be in a module
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

    # --- Home Configuration ---
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.sh1marin = {
      news.display = "silent";

      home = {
        username = "sh1marin";
        homeDirectory = "/home/sh1marin";
        stateVersion = "25.11";
      };

      imports = [
        self.homeModules.coding
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

      home.packages = [
        pkgs.ffmpeg
        pkgs.mtr
        pkgs.nexttrace
        pkgs.aria2
      ];

      programs.obs-studio.enable = true;
    };
  };
}
