{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
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
      nerd-fonts.fira-code
    ];

    xdg.configFile.kurisu-fontconfig = {
      recursive = true;
      source = ../../dotfile/fontconfig;
      target = "fontconfig";
    };
  };
}
