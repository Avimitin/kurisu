{ lib, ... }:
let
  allowedManagers = lib.types.enum [
    "tuigreet"
  ];
in
{
  imports = [ ./tuigreet.nix ];

  options.kurisu.os.login_manager = {
    enable = lib.mkEnableOption "Login Manager";

    profile = lib.mkOption {
      type = allowedManagers;
      description = "Profile for login manager";
      example = "tuigreet";
    };
  };
}
