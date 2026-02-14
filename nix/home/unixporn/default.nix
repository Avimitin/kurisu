{ lib, config, ... }:
let
  cfg = config.kurisu.unixporn;
  allowedStyle = lib.types.enum [
    "whitesur"
  ];
in
{
  imports = [
    ./whitesur.nix
  ];

  options.kurisu.unixporn = {
    enable = lib.mkEnableOption "Do ricing";

    style = lib.mkOption {
      type = lib.types.nullOr allowedStyle;
      description = "Select a style to enable";
      example = "whitesur";
    };

    gtk_settings = lib.mkOption {
      internal = true;
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "Configuration to the gtk home manager module";
    };

    qt_settings = lib.mkOption {
      internal = true;
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "Configuration to the qt home manager module";
    };
  };

  config = lib.mkIf cfg.enable {
    gtk = lib.mkIf (cfg.gtk_settings != null) cfg.gtk_settings;
    qt = lib.mkIf (cfg.qt_settings != null) cfg.qt_settings;
  };
}
