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

    home.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.fira-code
      nerd-fonts.im-writing
    ];

    fonts.fontconfig.hinting = "slight";
    fonts.fontconfig.subpixelRendering = "rgb";
    fonts.fontconfig.antialiasing = true;

    fonts.fontconfig.defaultFonts = {
      serif = [
        "Noto Serif CJK SC"
        "Noto Serif"
      ];
      sansSerif = [
        "Noto Sans CJK SC"
        "Noto Sans"
      ];
      monospace = [
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
