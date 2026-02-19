{ lib, ... }:
let
  allowedPlatform = lib.types.enum [
    "intel"
  ];
in
{
  imports = [ ./intel.nix ];

  options.kurisu.graphic = {
    enable = lib.mkEnableOption "Enable video card configuration";

    platform = lib.mkOption {
      type = lib.types.nullOr allowedPlatform;
      description = "Select one of the platform to configure";
      example = "intel";
    };
  };
}
