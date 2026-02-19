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
    self.nixosModules.login_manager

    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf (!config.kurisu.machines.thinkbook13.isInstall) {
    kurisu = {
      os.graphic = {
        enable = true;
        platform = "intel";
      };

      os.login_manager = {
        enable = true;
        profile = "tuigreet";
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
        self.homeModules.tools
      ];

      kurisu.hm.tools = {
        enable = true;
        enableLsp = true;
        enableAI = true;
        configureBash = true;
        extraPackages = [
          inputs.nvim.packages.${pkgs.stdenv.hostPlatform.system}.neovim # my neovim
        ];
      };

      programs.obs-studio.enable = true;
    };
  };
}
