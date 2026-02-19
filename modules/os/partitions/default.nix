# Requirement: disko module is installed
{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.kurisu.partitions;
  allowedProfile = lib.types.enum [
    "zfs-single-root"
  ];
in
{
  imports = [
    inputs.disko.nixosModules.disko

    # Profiles
    ./zfs-single-root.nix
  ];

  options.kurisu.partitions = {
    enable = lib.mkEnableOption "Enable Disko partition";

    profile = lib.mkOption {
      type = lib.types.nullOr allowedProfile;
      description = "Select an partition profile";
      example = "btrfs-gpt";
    };

    devices = lib.mkOption {
      internal = true;
      type = lib.types.attrs;
      description = "`disko.devices` settings";
    };
  };

  config = lib.mkIf cfg.enable {
    disko = {
      inherit (cfg) devices;
    };
  };
}
