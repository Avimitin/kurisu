{ lib, ... }:
let
  allowedStyle = lib.types.enum [
    "whitesur"
  ];
in
{
  imports = [
    ./whitesur.nix
  ];

  options.kurisu.hm.unixporn = {
    enable = lib.mkEnableOption "Do ricing";

    style = lib.mkOption {
      type = lib.types.nullOr allowedStyle;
      description = "Select a style to enable";
      example = "whitesur";
    };
  };
}
