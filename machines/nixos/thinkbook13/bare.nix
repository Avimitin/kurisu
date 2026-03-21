{
  lib,
  pkgs,
  self,
  inputs,
  modulesPath,
  ...
}:

{
  system.stateVersion = "25.11";

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    self.nixosModules.common-config
    self.nixosModules.partitions
    self.nixosModules.ovpn
    inputs.sops-nix.nixosModules.sops
  ];

  kurisu.partitions = {
    enable = true;
    profile = "zfs-single-root";
    zfs-single-root = {
      diskName = "/dev/nvme0n1";
      extraDatasets = {
        # Mozart's Sonata No.11
        "root/sonata" = {
          type = "zfs_fs";
          options = {
            encryption = "aes-256-gcm";
            keyformat = "passphrase";
            keylocation = "prompt";
          };
          mountpoint = "/sonata";
        };
      };
    };
  };

  # zfs required networking.hostId to be set
  networking.hostId = "d38083c3";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  networking.hostName = "thinkbook13";

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp44s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Enable networking
  networking.networkmanager = {
    enable = true;
    # plugins = [ pkgs.networkmanager-openvpn ];
    dns = "none";
  };

  kurisu.os.openvpn = {
    enable = true;
    servers = {
      whlab = {
        config = "config /sonata/whlab.ovpn ";
      };
    };
  };

  networking = {
    nameservers = lib.mkBefore [
      "172.25.15.1"
      "114.114.114.114"
    ];
  };

  networking.firewall.enable = lib.mkDefault false;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  programs.fish.enable = true;
  users.users.sh1marin = {
    isNormalUser = true;
    description = "sh1marin";
    extraGroups = [
      "networkmanager"
      "wheel"
      "plugdev"
    ];
    shell = pkgs.fish;
  };

  # Provide nh for system switch
  environment.systemPackages = [ pkgs.nh ];
}
