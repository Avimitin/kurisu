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
      nerd-fonts.fira-code
      nerd-fonts.im-writing
    ];

    xdg.configFile."fontconfig/conf.d" = {
      source = ../../dotfile/fontconfig/conf.d;
      recursive = true;
    };
  };
}
