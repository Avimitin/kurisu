{
  config,
  pkgs,
  self,
  inputs,
  ...
}:
let
  systemClosure = config.system.build.toplevel;
in
{
  imports = [
    self.nixosModules.meka
  ];

  system.stateVersion = "26.05";

  # Container rootfs, not a bare-metal machine: no kernel, no udev, no
  # bootloader. Boots under systemd-nspawn against the host kernel.
  boot.isContainer = true;

  networking.hostName = "meka";

  # systemd-nspawn's VirtualEthernet=yes (see meka.nspawn) creates the veth
  # host0 (guest) <-> ve-meka (host). The guest's stock
  # 80-container-host0.network brings host0 up via DHCP against the host-side
  # DHCP server (80-container-ve.network, run by the host's systemd-networkd).
  # No static addressing lives here; the host port mapping is in meka.nspawn.
  networking.useNetworkd = true;

  # NixOS's generic DHCP units (networking.useDHCP) target physical NICs only
  # (Kind=!*), which a container does not have; host0's DHCP comes from the
  # stock 80-container-host0.network shipped with systemd. Keep useDHCP off so
  # those unused physical-NIC units are not generated.
  networking.useDHCP = false;

  # The guest does not filter traffic. Port= in meka.nspawn forwards the
  # host's port 58964 to nginx on host0:80.
  networking.firewall.enable = false;

  # Let guest networkd pass the DHCP DNS server to guest systemd-resolved.
  # nspawn leaves resolv.conf alone for private networks, so the guest needs
  # its own resolver for model API requests.
  services.resolved.enable = true;
  networking.useHostResolvConf = false;

  # No Nix tooling or daemon inside the guest: meka is a pre-built closure
  # and never invokes nix at runtime. Removes the daemon as attack surface and
  # shrinks the image. The host's Nix daemon socket is never mounted into this
  # self-contained rootfs, so there is no trust boundary to bridge.
  nix.enable = false;

  kurisu.os.meka = {
    enable = true;
    bindAddress = "127.0.0.1";
    configDir = "/var/lib/meka/config";

    # The bearer token is bind-mounted in by the host (systemd-nspawn
    # `--bind-ro=<host-token>:/etc/meka/token:rootidmap`), never baked into
    # this image.
    tokenFile = "/etc/meka/token";

    webUi = {
      enable = true;
      virtualHost = "meka";

      # Bind all interfaces inside the guest so the host's port mapping can
      # reach nginx. Access control is enforced at the outer boundary (nspawn
      # user namespace + private veth + Port= + host firewall), not by the
      # loopback default of a bare-metal host.
      listenAddresses = [
        "0.0.0.0"
        "[::]"
      ];
    };
  };

  # Make the interactive account/profile commands use the same persistent
  # config and credential store as meka.service.
  environment.systemPackages = [ pkgs.meka ];
  environment.variables = {
    MEKA_CONFIG_DIR = "/var/lib/meka/config";
    MEKA_DATA_DIR = "/var/lib/meka";
  };

  # Seed the writable config only once. Subsequent `meka account` and
  # `meka profile` changes live on the persistent host bind mount.
  systemd.services.meka.preStart = ''
    ${pkgs.coreutils}/bin/install -d -m 0700 /var/lib/meka/config
    if [ ! -e /var/lib/meka/config/config.toml ]; then
      ${pkgs.coreutils}/bin/install -m 0600 /etc/meka/config.toml /var/lib/meka/config/config.toml
    fi
  '';

  # Self-contained rootfs tarball for `systemd-nspawn -D <extracted>`.
  #
  # systemd-nspawn --boot looks for init at /usr/lib/systemd/systemd, then
  # /lib/systemd/systemd, then /sbin/init, so we graft the toplevel init
  # script to /sbin/init (rather than copying the whole toplevel to /init,
  # which nspawn never looks at). The full toplevel closure is still copied
  # into the tarball's own /nix/store, and the system profile symlink is added
  # so the image matches a normal NixOS boot layout.
  system.build.tarball = pkgs.callPackage (inputs.nixpkgs + "/nixos/lib/make-system-tarball.nix") {
    fileName = "meka-rootfs";

    storeContents = [
      {
        object = systemClosure;
        symlink = "/nix/var/nix/profiles/system";
      }
    ];

    contents = [
      {
        source = "${systemClosure}/etc/os-release";
        target = "/etc/os-release";
      }
      {
        source = "${systemClosure}/init";
        target = "/sbin/init";
      }
    ];

    extraArgs = "--owner=0";

    # make-system-tarball executes this value as a command path; keep the
    # shell in its own derivation to avoid word-splitting into archive paths.
    extraCommands = pkgs.writeShellScript "prepare-meka-rootfs" ''
      mkdir -p var/lib/meka
      chmod 0755 var/lib/meka
    '';
  };
}
