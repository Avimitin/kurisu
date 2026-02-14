{
  lib,
  pkgs,
  config,
  self,
  modulesPath,
  ...
}:

{
  system.stateVersion = "25.11";

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    self.nixosModules.partitions
  ];

  kurisu.partitions = {
    enable = true;
    profile = "zfs-single-root";
    zfs-single-root.diskName = "/dev/nvme0n1";
  };

  # zfs required networking.hostId to be set
  networking.hostId = "d38083c3";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

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
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  services.xserver.videoDrivers = [ "modesetting" ];

  # Enable networking
  networking.networkmanager = {
    enable = true;
    # plugins = [ pkgs.networkmanager-openvpn ];
  };

  kurisu.openvpn = {
    enable = true;
    servers = {
      whlab = {
        config = "config /var/lib/kurisu/whlab.ovpn ";
        up = ''
          resolvectl default-route wlp44s0 no
          resolvectl dns tap0 172.25.15.1
        '';
        down = ''
          resolvectl default-route wlp44s0 yes
        '';
      };
    };
  };

  networking = {
    nameservers = lib.mkBefore [
      "172.25.15.1"
    ];
  };
  services.resolved.enable = true;

  networking.firewall.enable = lib.mkDefault false;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
}
