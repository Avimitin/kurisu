{
  config,
  lib,
  ...
}:
let
  cfg = config.kurisu.openvpn;
in
with lib;
{
  imports = [ ];

  options.kurisu.openvpn = {
    enable = mkEnableOption "Create a OpenVPN instance";

    servers = mkOption {
      type = lib.types.attrs;
      example = {
        server1 = {
          config = " config /path/to/server1.ovpn ";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.openvpn.servers = cfg.servers;

    systemd.services = lib.mkMerge (
      lib.mapAttrsToList (name: _: {
        "openvpn-${name}".unitConfig = {
          After = lib.mkForce [ "network-online.target" ];
          Wants = lib.mkForce [ "network-online.target" ];
        };
      }) cfg.servers
    );
  };
}
