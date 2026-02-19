{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.terminal;
in
{
  imports = [ ];

  options.kurisu.terminal.foot = {
    settingsPath = lib.mkOption {
      type = lib.types.path;
      default = ../../../dotfile/foot/foot.ini;
      description = "path to config, default to dotfile/foot/foot.ini";
    };

    enableServer = lib.mkEnableOption "Enable systemd foot terminal server service.";
  };

  config = lib.mkIf (cfg.enable && cfg.type == "foot") {
    kurisu.terminal.package = pkgs.foot;

    xdg.configFile."foot/foot.ini".source = cfg.foot.settingsPath;

    systemd.user.services = lib.mkIf cfg.foot.enableServer {
      foot = {
        Unit = {
          Description = "Fast, lightweight and minimalistic Wayland terminal emulator.";
          Documentation = "man:foot(1)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${cfg.package}/bin/foot --server";
          Restart = "on-failure";
          OOMPolicy = "continue";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}
