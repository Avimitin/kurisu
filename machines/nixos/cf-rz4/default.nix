{ pkgs, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    ./hardware.nix
    ./display.nix
  ];

  system.stateVersion = "26.05";
  networking.hostName = "cf-rz4";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep routine boot output off the console; journalctl retains system logs.
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "systemd.show_status=false"
    "rd.systemd.show_status=false"
    "udev.log_level=3"
    "rd.udev.log_level=3"
  ];

  services.openssh = {
    enable = true;
  };

  users.users.sh1marin = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];
    # Provisioned by nixos-anywhere --extra-files, outside the Nix store.
    hashedPasswordFile = "/var/lib/cf-rz4/sh1marin-password";
  };
  users.users.root.hashedPasswordFile = "/var/lib/cf-rz4/root-password";

  # Retain remote administration without an interactive password prompt.
  security.sudo.extraRules = [
    {
      users = [ "sh1marin" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Stay available as a server even with the lid closed or XFCE idle.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
  environment.xfce.excludePackages = [ pkgs.xfce4-power-manager ];

  services.fstrim.enable = true;
  services.thermald.enable = true;
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # Allow this existing sudo administrator to deploy locally built closures
    # with nixos-rebuild --target-host.
    trusted-users = [ "sh1marin" ];
    # The Broadwell CPU has two physical cores.
    max-jobs = 1;
    cores = 2;
  };
  environment.systemPackages = with pkgs; [
    (chromium.override {
      # Automatic login leaves the keyring locked. Use Chromium's basic store
      # to avoid unlock prompts; saved passwords lose keyring encryption.
      commandLineArgs = "--password-store=basic";
    })
    git
    vim
    htop
    mpv
    yt-dlp
    qmmp
  ];
}
