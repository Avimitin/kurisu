{
  self,
  inputs,
  pkgs,
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

  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  programs.ssh = {
    enableAskPassword = true;
    extraConfig = ''
      Host github.com ssh.github.com
        IdentityAgent none
    '';
  };
  programs.vim.package = pkgs.vim-full;
  environment.systemPackages = [ pkgs.moonlight-qt ];
  nix.distributedBuilds = true;
nix.buildMachines = [
  {
    hostName = "10.x.y.z";                       # the IP, not an alias
    protocol = "ssh-ng";
    sshUser = "root";
    sshKey = "/root/.ssh/id_ed25519_henan_builder";
    system = "x86_64-linux";
    maxJobs = 16;                                # see sizing below
    speedFactor = 1;
    supportedFeatures = [ "big-parallel" "kvm" "nixos-test" "benchmark" ];
    publicHostKey = "<base64 -w0 of the builder's /etc/ssh/ssh_host_ed25519_key.pub>";
  }
];


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
      pkgs.tigervnc
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
