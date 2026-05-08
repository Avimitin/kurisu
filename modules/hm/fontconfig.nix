{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.kurisu.hm.fontconfig;
in
{
  options.kurisu.hm.fontconfig = {
    enable = mkEnableOption "Enable fontconfig with Noto Sans CJK SC for Chinese";
  };

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = true;

    home.packages =
      with pkgs;
      let
        apple-sf-mono = mkAppleFonts {
          fontName = "SF-Mono";
          hash = "sha256-bUoLeOOqzQb5E/ZCzq0cfbSvNO1IhW1xcaLgtV2aeUU=";
        };
        apple-sf-pro = mkAppleFonts {
          fontName = "SF-Pro";
          hash = "sha256-W0sZkipBtrduInk0oocbFAXX1qy0Z+yk2xUyFfDWx4s=";
        };
        apple-newyork = mkAppleFonts {
          fontName = "NY";
          hash = "sha256-HC7ttFJswPMm+Lfql49aQzdWR2osjFYHJTdgjtuI+PQ=";
        };
      in
      [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        nerd-fonts.fira-code
        nerd-fonts.im-writing
        apple-sf-mono
        apple-sf-pro
        apple-newyork
      ];

    fonts.fontconfig.hinting = "slight";
    fonts.fontconfig.subpixelRendering = "rgb";
    fonts.fontconfig.antialiasing = true;

    fonts.fontconfig.defaultFonts = {
      serif = [
        "New York"
        "Noto Serif CJK SC"
        "Noto Serif"
      ];
      sansSerif = [
        "SF Pro"
        "Noto Sans CJK SC"
        "Noto Sans"
      ];
      monospace = [
        "SF Mono"
        "iMWritingMono Nerd Font Mono"
        "FiraCode Nerd Font Mono"
        "Noto Sans Mono CJK SC"
        "Noto Sans Mono"
      ];
      emoji = [
        "Noto Color Emoji"
      ];
    };

  };
}
