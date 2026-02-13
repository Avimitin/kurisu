{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.basic-env;
in
with lib;
{
  imports = [ ];

  options.kurisu.basic-env = {
    enable = mkEnableOption "Minimal Wayland Environment";
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --asterisks --remember --remember-session";
          user = "greeter";
        };
      };
    };

    programs.niri.enable = true;

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      nerd-fonts.fira-code
    ];

    environment.systemPackages = with pkgs; [
      vim
      wget
      curl
      git
      nautilus
      firefox
    ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      auto-optimise-store = true;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];
  };
}
