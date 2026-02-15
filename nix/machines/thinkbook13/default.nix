{ lib, ... }:
{
  imports = [
    ./bare.nix
    ./desktop.nix
  ];

  options.kurisu.thinkbook13 = {
    isInstall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enables a minimal NixOS build layer.

        Because this ThinkBook 13 only has 16GiB of RAM, the Live CD environment
        lacks the ramdisk space required to build the full system closure. To work
        around this, the configuration is split into multiple layers. Setting this
        option to `true` applies a basic configuration, creating a minimal bootable
        environment from which a full `nixos-rebuild` can easily be executed.
      '';
    };
  };
}
