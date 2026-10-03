# Both frontends use the same meka daemon, persistent state, and API proxy.
{ moduleName, frontendName }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    optionalString
    ;
  cfg = config.kurisu.os.${moduleName};

  files = cfg.webUi.files;
  # nginx quoted arguments also need literal dollar signs escaped.
  nginxQuote = value: "\"${lib.replaceStrings [ "\\" "\"" "$" ] [ "\\\\" "\\\"" "\\$" ] value}\"";
  fileLocations = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: mount: ''
      location ^~ /files/${name}/ {
        alias ${nginxQuote (lib.removeSuffix "/" mount.root + "/")};
        autoindex off;
        if ($uri ~ /$) { return 404; }
        limit_except GET { deny all; }
        add_header Content-Disposition "attachment" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Content-Security-Policy "sandbox; default-src 'none'" always;
        add_header Cache-Control "no-store" always;
      }
    '') files.mounts
  );
  fileServerConfig = pkgs.writeText "${frontendName}-files-nginx.conf" ''
    daemon off;
    master_process off;
    pid /run/${frontendName}-files/nginx.pid;
    error_log stderr;
    events {}
    http {
      access_log off;
      default_type application/octet-stream;
      client_body_temp_path /run/${frontendName}-files/client;
      proxy_temp_path /run/${frontendName}-files/proxy;
      fastcgi_temp_path /run/${frontendName}-files/fastcgi;
      uwsgi_temp_path /run/${frontendName}-files/uwsgi;
      scgi_temp_path /run/${frontendName}-files/scgi;
      server {
        listen 127.0.0.1:${toString files.port};
        server_name localhost;
        auth_basic "Mekadsh files";
        auth_basic_user_file ${nginxQuote files.basicAuthFile};
        location / { return 404; }
        ${fileLocations}
      }
    }
  '';
  runtimeConfig = pkgs.writeText "mekadsh-config.json" (
    builtins.toJSON {
      version = 1;
      connections = [
        (
          {
            apiBaseUrl = "/api/";
          }
          // lib.optionalAttrs files.enable {
            files = {
              auth = "basic";
              mounts = lib.mapAttrsToList (name: mount: {
                inherit (mount) pathPrefix;
                urlPrefix = "/files/${name}/";
              }) files.mounts;
            };
          }
        )
      ];
    }
  );

  # Every subsystem takes one read and one write scope. The web UI drives all
  # of them, so grant a full set.
  allScopes = [
    "sessions:r"
    "sessions:w"
    "skills:r"
    "skills:w"
    "memory:r"
    "memory:w"
    "schedule:r"
    "schedule:w"
    "mcp:r"
    "mcp:w"
  ];

  # Written to /etc/meka/config.toml. The bearer token lives in a separate
  # file (cfg.tokenFile, by default /etc/meka/token) so no secret is copied
  # into the world-readable Nix store. The file itself is supplied by the
  # operator (e.g. a systemd-nspawn bind mount), not by this module.
  mekaConfig = ''
    [permissions]
    default = "unrestricted"

    [serve]
    bind = "${cfg.bindAddress}:${toString cfg.port}"
    ${optionalString (cfg.streamReattachGrace != null) ''
      stream_reattach_grace = ${builtins.toJSON cfg.streamReattachGrace}
    ''}
    ${optionalString (cfg.corsAllowedOrigins != [ ]) ''
      cors_allowed_origins = ${builtins.toJSON cfg.corsAllowedOrigins}
    ''}

    [[serve.tokens]]
    token_file = ${builtins.toJSON cfg.tokenFile}
    description = "${frontendName}"
    scopes = ${builtins.toJSON allScopes}
  '';
in
{
  options.kurisu.os.${moduleName} = {
    enable = mkEnableOption "the meka AI agent web service with ${frontendName}";

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port the meka HTTP API listens on.";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address the meka HTTP API listens on.";
    };

    streamReattachGrace = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        How long a streaming HTTP turn continues after its client disconnects.
        Null keeps meka's 30-second default.
      '';
    };

    configDir = mkOption {
      type = types.str;
      default = "/etc/meka";
      description = "Directory containing meka's config.toml; CLI edits require it to be writable.";
    };

    tokenFile = mkOption {
      type = types.str;
      default = "/etc/meka/token";
      description = ''
        Path to a file containing the meka API bearer token (one line,
        trimmed). The token is referenced from `meka/config.toml`, so the
        secret itself never enters the Nix store. Keep this as a quoted
        string (e.g. "/etc/meka/token") rather than an unquoted path literal
        so it is not copied into the store.
      '';
    };

    corsAllowedOrigins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Browser origins allowed to call the API cross-origin. Empty (the
        default) means no CORS headers, which is correct when the web UI is
        served from the same origin through the nginx reverse proxy.
      '';
    };

    webUi = {
      files = {
        enable = mkEnableOption "authenticated current-file previews and downloads for mekadsh";
        port = mkOption {
          type = types.port;
          default = 8081;
          description = "Loopback port for the authenticated file server.";
        };
        basicAuthFile = mkOption {
          type = types.str;
          default = "";
          description = "Absolute path to an htpasswd file readable by the meka service user. Supply it at runtime, not through the Nix store.";
        };
        mounts = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                pathPrefix = mkOption {
                  type = types.str;
                  description = "Absolute directory as seen by meka, used for frontend path mapping.";
                };
                root = mkOption {
                  type = types.str;
                  description = "Absolute directory served by the file service. Symlinks follow the service user's filesystem permissions.";
                };
              };
            }
          );
          default = {
            root = {
              pathPrefix = "/";
              root = "/";
            };
          };
          description = "Named filesystem exports, served at /files/<name>/. The default intentionally grants authenticated users full reads under meka's Unix identity.";
        };
      };
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Serve the ${frontendName} static SPA and reverse-proxy the API to the meka
          service under `/api/`, so the browser talks to meka same-origin and
          no CORS is required.
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.${frontendName};
        defaultText = lib.literalExpression "pkgs.${frontendName}";
        description = "Static frontend package served by nginx.";
      };

      virtualHost = mkOption {
        type = types.str;
        default = "meka";
        description = "Name of the nginx virtual host (also its server_name).";
      };

      defaultVhost = mkOption {
        type = types.bool;
        default = true;
        description = "Make this nginx virtual host the catch-all default server.";
      };

      listenAddresses = mkOption {
        type = types.listOf types.str;
        default = [
          "127.0.0.1"
          "[::1]"
        ];
        description = ''
          Addresses nginx listens on for this virtual host. The default binds
          only the loopback interfaces. If you expose it beyond localhost
          (e.g. a VPN or Tailscale interface), keep it on a trusted network
          and terminate TLS in front of it -- the meka bearer token is a
          bearer credential and must never travel over plain HTTP.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tokenFile != "";
        message = "kurisu.os.${moduleName}.tokenFile must point at a file containing the API bearer token.";
      }
    ]
    ++ lib.optionals files.enable [
      {
        assertion = frontendName == "mekadsh" && cfg.webUi.enable;
        message = "File access requires the mekadsh web UI.";
      }
      {
        assertion =
          lib.hasPrefix "/" files.basicAuthFile && !(lib.hasPrefix "/nix/store/" files.basicAuthFile);
        message = "File access requires a runtime htpasswd file outside the Nix store.";
      }
      {
        assertion = files.port != cfg.port && files.mounts != { };
        message = "File access requires a separate port and at least one mount.";
      }
      {
        assertion =
          lib.all (name: builtins.match "[a-zA-Z0-9_-]+" name != null) (builtins.attrNames files.mounts)
          && lib.all (mount: lib.hasPrefix "/" mount.pathPrefix && lib.hasPrefix "/" mount.root) (
            builtins.attrValues files.mounts
          );
        message = "File mount names must use letters, digits, underscores, or hyphens, and mount paths must be absolute.";
      }
    ];

    systemd.services.${frontendName + "-files"} = mkIf files.enable {
      description = "Authenticated filesystem reads for ${frontendName}";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nginx}/bin/nginx -c ${fileServerConfig} -p /run/${frontendName}-files/";
        Restart = "on-failure";
        RuntimeDirectory = "${frontendName}-files";
        RuntimeDirectoryMode = "0700";
        User = config.systemd.services.meka.serviceConfig.User;
        Group = config.systemd.services.meka.serviceConfig.Group;
        SupplementaryGroups = config.systemd.services.meka.serviceConfig.SupplementaryGroups or [ ];
        NoNewPrivileges = true;
        # Full filesystem visibility is intentional, matching the meka account.
        # Never enable DAV, CGI, or directory listing in this service.
      };
    };

    environment.etc."meka/config.toml".text = mekaConfig;

    # A normal root-permission systemd service. Containment (user namespaces,
    # networking, token bind-mount) is an outer-boundary concern handled by
    # whatever runs this system (e.g. systemd-nspawn), not by the service.
    systemd.services.meka = {
      description = "meka serve (HTTP API)";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # shell_execute invokes `sh` by name, so it must be on the service's
      # PATH (the interactive system profile is not inherited by systemd).
      path = [ pkgs.bashInteractive ];

      environment = {
        MEKA_CONFIG_DIR = cfg.configDir;
        MEKA_DATA_DIR = "/var/lib/meka";
        RUST_LOG = "meka=info";
      };

      serviceConfig = {
        ExecStart = "${pkgs.meka}/bin/meka serve";
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = "meka";
        StateDirectoryMode = "0700";
        User = "root";
        Group = "root";
      };
    };

    services.nginx = mkIf cfg.webUi.enable {
      enable = true;

      virtualHosts.${cfg.webUi.virtualHost} = {
        default = cfg.webUi.defaultVhost;
        listenAddresses = cfg.webUi.listenAddresses;
        root = cfg.webUi.package;

        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };

        locations."= /mekadsh-config.json" = mkIf (frontendName == "mekadsh") {
          alias = runtimeConfig;
          extraConfig = ''
            default_type application/json;
            add_header Cache-Control "no-store" always;
          '';
        };

        locations."^~ /files/" = mkIf files.enable {
          proxyPass = "http://127.0.0.1:${toString files.port}";
          extraConfig = ''
            proxy_set_header Authorization $http_authorization;
            proxy_set_header Cookie "";
            proxy_buffering off;
            proxy_cache off;
          '';
        };

        locations."/api/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}/";
          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # SSE streaming (turn events): drop the client keep-alive header,
            # disable buffering, and hold idle connections open.
            proxy_set_header Connection "";
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 1h;
          '';
        };
      };
    };

    # Avoid a burst of 502s on boot: wait for meka before nginx.
    systemd.services.nginx = mkIf cfg.webUi.enable {
      after = [ "meka.service" ];
    };
  };
}
