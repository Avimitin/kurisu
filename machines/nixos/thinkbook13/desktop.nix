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
    self.nixosModules.udev

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
        enableFontconfig = true;

        terminal = {
          enable = true;
          type = "foot";
        };
      };

      os.canokey.enableRootlessAccess = true;
    };

    services.udisks2.enable = true;
    services.nginx = {
      enable = true;

      # Pull in the RTMP module natively
      additionalModules = [ pkgs.nginxModules.rtmp ];

      # Append the RTMP configuration to the root context of the nginx.conf
      appendConfig = ''
        rtmp {
          server {
            listen 1935;
            chunk_size 4096;

            application live {
              live on;
              record off;
            }
          }
        }
      '';
    };

    # --- Home Configuration ---
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.sh1marin = {
      news.display = "silent";

      home = {
        username = "sh1marin";
        homeDirectory = "/home/sh1marin";
        stateVersion = "26.05";
      };

      imports = [
        self.homeModules.tools
        self.homeModules.fontconfig

        inputs.nvim.homeModules.nvim
      ];

      home.packages = [
        pkgs.kitty
        pkgs.telegram-desktop
        pkgs.zathura
        pkgs.kdePackages.gwenview
      ];

      kurisu.hm.tools = {
        enable = true;
        enableLsp = true;
        enableAI = true;
        configureBash = true;
        configureFish = true;
      };

      kurisu.hm.fontconfig.enable = true;

      programs.git.settings = {
        user = {
          name = "Avimitin";
          email = "dev@avimit.in";
        };
      };

      programs.obs-studio.enable = true;
      programs.chromium.enable = true;
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
  };
}
