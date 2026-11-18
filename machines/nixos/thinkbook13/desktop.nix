{
  self,
  inputs,
  pkgs,
  lib,
  config,
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
        type = "kitty";
      };
    };

    os.canokey.enableRootlessAccess = true;
  };

  services.udisks2.enable = true;

  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  programs.ssh = {
    enableAskPassword = true;
    askPassword = "${pkgs.egui-askpass}/bin/egui-askpass";
  };

  # The askpass helper needs WAYLAND_DISPLAY from the running compositor, so
  # only start the agent once the niri session has imported it instead of at
  # login (default.target).  The socket still comes up with sockets.target so
  # SSH_AUTH_SOCK is set in the user manager environment before niri starts.
  systemd.user.services.gcr-ssh-agent = {
    environment.SSH_ASKPASS = "${pkgs.egui-askpass}/bin/egui-askpass";

    wantedBy = lib.mkForce [ "graphical-session.target" ];
    after = [ "niri.service" ];
    partOf = [ "graphical-session.target" ];
  };

  programs.vim.package = pkgs.vim-full;

  environment.systemPackages = [
    pkgs.egui-askpass
    pkgs.moonlight-qt
    pkgs.akira-companion
    pkgs.iets
  ];

  nix.distributedBuilds = true;

  # --- Home Configuration ---
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sh1marin = {
    news.display = "silent";

    home = {
      username = "sh1marin";
      homeDirectory = "/home/sh1marin";
      stateVersion = "26.05";

      file.".vimrc".source = ../../../dotfile/vim/.vimrc;
    };

    imports = [
      self.homeModules.tools
      self.homeModules.fontconfig
      self.homeModules.zed

      inputs.sops-nix.homeManagerModules.sops
    ];

    home.packages = [
      pkgs.kitty
      pkgs.telegram-desktop
      pkgs.zathura
      pkgs.loupe
      pkgs.flameshot
    ];

    kurisu.hm.tools = {
      enable = true;
      enableLsp = true;
      enableAI = true;
      configureBash = true;
      configureFish = true;
    };

    kurisu.hm.fontconfig.enable = true;
    kurisu.hm.zed.enable = true;

    programs.git.settings = {
      user = {
        name = "Avimitin";
        email = "dev@avimit.in";
      };
    };

    programs.obs-studio.enable = true;
    programs.chromium.enable = true;

    sops = {
      age.keyFile = "${config.home-manager.users.sh1marin.home.homeDirectory}/.config/sops/age/keys.txt";

      secrets."nix_access_tokens" = {
        sopsFile = ../../../secrets/tokens.yaml;
      };
    };

    nix.extraOptions = ''
      !include ${config.home-manager.users.sh1marin.sops.secrets."nix_access_tokens".path}
      !include ${config.home-manager.users.sh1marin.xdg.configHome}/nix/substituter.conf
    '';
  };
}
