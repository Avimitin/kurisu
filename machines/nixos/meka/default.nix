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
  # DHCPServer (80-container-ve.network, run by the host's systemd-networkd).
  # No static addressing lives here; the host port mapping is in meka.nspawn.
  networking.useNetworkd = true;

  # NixOS's generic DHCP units (networking.useDHCP) target physical NICs only
  # (Kind=!*), which a container does not have; host0's DHCP comes from the
  # stock 80-container-host0.network shipped with systemd. Keep useDHCP off so
  # those unused physical-NIC units are not generated.
  networking.useDHCP = false;

  # We only need networkd to bring up the veth; do not run systemd-resolved
  # inside the guest (it conflicts with the container default of reusing the
  # host's /etc/resolv.conf, and meka needs no in-guest DNS resolution).
  services.resolved.enable = false;
  networking.useHostResolvConf = true;

  # No Nix tooling or daemon inside the guest: meka is a pre-built closure
  # and never invokes nix at runtime. Removes the daemon as attack surface and
  # shrinks the image. The host's Nix daemon socket is never mounted into this
  # self-contained rootfs, so there is no trust boundary to bridge.
  nix.enable = false;

  kurisu.os.meka = {
    enable = true;

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
