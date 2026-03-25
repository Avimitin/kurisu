{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf;

  cfg = config.kurisu.os.openvpn;
in
{
  imports = [ ];

  options.kurisu.os.openvpn = {
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

    networking.networkmanager.dispatcherScripts = mkIf config.networking.networkmanager.enable (
      lib.mapAttrsToList (vpnName: _: {
        # We prefix with "10-" as NetworkManager runs these in alphabetical order
        source = pkgs.writeText "10-restart-openvpn" ''
          #!/bin/sh
          interface="$1"
          action="$2"

          case "$interface" in
            wlp*|enp*|eth*) ;;
            tun*|tap*) exit 0;;
            *) exit 0;;
          esac

          case "$action" in
            up|connectivity-change)
              logger "NM Dispatcher: $interface $action -- restarting OpenVPN"
              ${pkgs.systemd}/bin/systemctl try-restart openvpn-${vpnName}.service
              ;;
          esac
        '';
        type = "basic";
      }) cfg.servers
    );

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
