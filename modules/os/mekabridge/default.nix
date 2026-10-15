{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.os.mekabridge;
  python = pkgs.python3.withPackages (p: [ p.tomlkit ]);
  runtimeConfig = "/run/mekabridge/config.toml";
  settings = pkgs.writeText "mekabridge-settings.json" (
    builtins.toJSON {
      mekaConfig = "${cfg.mekaConfigDir}/config.toml";
      mekaToken = "${cfg.mekaConfigDir}/mekabridge-token";
      telegramToken = cfg.telegramTokenFile;
      telegramSettings = cfg.telegramSettingsFile;
      inherit runtimeConfig;
      bridge = {
        meka = {
          base_url = cfg.mekaUrl;
          token_file = "${cfg.mekaConfigDir}/mekabridge-token";
        };
        session = {
          permission = cfg.permission;
          cwd = cfg.workingDirectory;
        };
        mcp.bind = "127.0.0.1:${toString cfg.port}";
        storage = {
          path = "/var/lib/mekabridge/mekabridge.db";
          attachment_dir = "/var/lib/mekabridge/attachments";
        };
      };
      server = {
        name = "mekabridge";
        transport = "http";
        url = "http://127.0.0.1:${toString cfg.port}/mcp";
        required = true;
        eager_load_tools = [
          "message_send"
          "conversation_list"
        ];
      };
    }
  );
  prepare = "${python}/bin/python ${./prepare.py} ${settings}";
in
{
  options.kurisu.os.mekabridge = {
    enable = lib.mkEnableOption "the Telegram bridge for the local meka service";
    mekaConfigDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/meka/config";
      description = "Writable meka configuration directory; existing accounts and profiles are preserved.";
    };
    mekaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9100;
    };
    telegramTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/mekabridge/telegram-token";
      description = "Runtime file containing the Telegram bot token. Empty means setup is pending.";
    };
    telegramSettingsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/mekabridge/telegram.toml";
      description = "Runtime TOML file with allowed_users and allowed_chats arrays of numeric Telegram IDs.";
    };
    permission = lib.mkOption {
      type = lib.types.enum [
        "read"
        "workspace"
        "unrestricted"
      ];
      default = "read";
      description = "Permission level of the bridge's meka session.";
    };
    workingDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/srv/meka-workspace";
      description = "Workspace created for new bridge sessions. Move existing sessions through meka's session API.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.workingDirectory && cfg.workingDirectory != "/";
        message = "mekabridge needs an absolute workingDirectory below the filesystem root.";
      }
      {
        assertion =
          lib.all (path: cfg.workingDirectory != path && !(lib.hasPrefix "${path}/" cfg.workingDirectory))
            [
              cfg.mekaConfigDir
              config.systemd.services.meka.environment.MEKA_DATA_DIR
            ];
        message = "mekabridge workingDirectory must be outside meka's private config and data directories.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.mekaConfigDir && !(lib.hasPrefix "/nix/store/" cfg.mekaConfigDir);
        message = "mekabridge needs a writable mekaConfigDir outside the Nix store.";
      }
      {
        assertion = lib.all (p: lib.hasPrefix "/" p && !(lib.hasPrefix "/nix/store/" p)) [
          cfg.telegramTokenFile
          cfg.telegramSettingsFile
        ];
        message = "mekabridge Telegram credentials and allowlists must be runtime files outside the Nix store.";
      }
    ];

    environment.systemPackages = [ pkgs.mekabridge ];
    environment.variables.MEKABRIDGE_CONFIG = runtimeConfig;

    systemd.tmpfiles.rules = [
      "d ${cfg.workingDirectory} 0700 ${config.systemd.services.meka.serviceConfig.User} ${config.systemd.services.meka.serviceConfig.Group} -"
    ];

    systemd.services.mekabridge = {
      description = "Telegram bridge for meka";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      before = [ "meka.service" ];
      serviceConfig = {
        ExecCondition = "${prepare} check";
        ExecStartPre = "${prepare} bridge";
        ExecStart = "${pkgs.mekabridge}/bin/mekabridge --config ${runtimeConfig}";
        Restart = "always";
        RestartSec = "5s";
        RuntimeDirectory = "mekabridge";
        RuntimeDirectoryMode = "0700";
        StateDirectory = "mekabridge";
        StateDirectoryMode = "0700";
        # Match meka's identity so attachments and runtime token files are shared.
        User = config.systemd.services.meka.serviceConfig.User;
        Group = config.systemd.services.meka.serviceConfig.Group;
        UMask = "0077";
        NoNewPrivileges = true;
      };
    };

    systemd.services.meka = {
      wants = [ "mekabridge.service" ];
      after = [ "mekabridge.service" ];
      # The guest seeds its writable config first. Only the bridge's entries are
      # reconciled here; provider accounts, profiles and other MCP servers remain.
      preStart = lib.mkAfter ''
        ${prepare} meka
      '';
    };
  };
}
