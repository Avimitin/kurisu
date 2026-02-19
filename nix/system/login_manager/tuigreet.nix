{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.os.login_manager;
in
{
  imports = [ ];

  config = lib.mkIf (cfg.enable && cfg.profile == "tuigreet") {
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
  };
}
