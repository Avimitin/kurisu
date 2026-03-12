{ lib, config, ... }:
let
  cfg = config.kurisu.hm.terminal;
  allowedType = lib.types.enum [
    "foot"
    "alacritty"
    "kitty"
    "ghostty"
  ];
in
{
  imports = [
    ./foot.nix
    ./ghostty.nix
    ./alacritty.nix
    ./kitty.nix
  ];

  options.kurisu.hm.terminal = {
    enable = lib.mkEnableOption "Enable Terminal customization";

    type = lib.mkOption {
      type = lib.types.nullOr allowedType;
      description = ''
        Select an terminal option to enable.
      '';
      example = "foot";
    };

    package = lib.mkOption {
      internal = true;
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        The terminal package.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (cfg.package != null) [ cfg.package ];
  };
}
