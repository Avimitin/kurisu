{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.programs.gram;
  jsonFormat = pkgs.formats.json { };
  json5 = pkgs.python3Packages.toPythonApplication pkgs.python3Packages.json5;

  impureConfigMerger = empty: jqOperation: path: staticSettings: ''
    mkdir -p "$(dirname ${lib.escapeShellArg path})"
    if [ ! -e ${lib.escapeShellArg path} ]; then
      echo ${lib.escapeShellArg empty} > ${lib.escapeShellArg path}
    fi
    dynamic="$(${lib.getExe json5} --as-json ${lib.escapeShellArg path} 2>/dev/null || echo ${lib.escapeShellArg empty})"
    static="$(cat ${lib.escapeShellArg staticSettings})"
    merged="$(${lib.getExe pkgs.jq} -n ${lib.escapeShellArg jqOperation} --argjson dynamic "$dynamic" --argjson static "$static")"
    printf '%s\n' "$merged" > ${lib.escapeShellArg path}
    unset dynamic static merged
  '';

  editorEnv = {
    EDITOR = "${cfg.package.meta.mainProgram or "gram"} --wait";
    VISUAL = "${cfg.package.meta.mainProgram or "gram"} --wait";
  };
in
{
  # Home Manager does not currently provide a Gram program module.
  options.programs.gram = {
    enable = lib.mkEnableOption "Gram, a private and telemetry-free fork of Zed";

    package = lib.mkPackageOption pkgs "gram" { nullable = true; };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.nil ]";
      description = "Extra packages available to Gram.";
    };

    mutableUserSettings = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether Gram may update settings.jsonc.";
    };

    mutableUserKeymaps = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether Gram may update keymap.jsonc.";
    };

    mutableUserTasks = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether Gram may update tasks.jsonc.";
    };

    mutableUserDebug = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether Gram may update debug.jsonc.";
    };

    userSettings = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = {
        vim_mode = true;
        ui_font_size = 16;
        buffer_font_size = 16;
      };
      description = "Configuration written to Gram's settings.jsonc.";
    };

    userKeymaps = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = literalExpression ''
        [
          {
            context = "Workspace";
            bindings.ctrl-shift-t = "workspace::NewTerminal";
          }
        ]
      '';
      description = "Configuration written to Gram's keymap.jsonc.";
    };

    userTasks = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          label = "Format Code";
          command = "nix";
          args = [
            "fmt"
            "$GRAM_WORKTREE_ROOT"
          ];
        }
      ];
      description = "Global tasks written to Gram's tasks.jsonc.";
    };

    userDebug = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          label = "Go (Delve)";
          adapter = "Delve";
          program = "$GRAM_FILE";
          request = "launch";
          mode = "debug";
        }
      ];
      description = "Global debug configurations written to Gram's debug.jsonc.";
    };

    installRemoteServer = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether to link Gram's remote server binary into ~/.gram_server so
        another Gram client can connect to this machine.
      '';
    };

    themes = mkOption {
      type = types.attrsOf (
        types.oneOf [
          jsonFormat.type
          types.path
          types.lines
        ]
      );
      default = { };
      description = ''
        Themes written to $XDG_CONFIG_HOME/gram/themes/<name>.json.
      '';
    };

    defaultEditor = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to set `gram --wait` as EDITOR and VISUAL.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.extraPackages != [ ] -> cfg.package != null;
        message = "programs.gram.extraPackages requires a non-null programs.gram.package";
      }
      {
        assertion = cfg.defaultEditor -> cfg.package != null;
        message = "programs.gram.defaultEditor requires a non-null programs.gram.package";
      }
      {
        assertion =
          cfg.installRemoteServer
          -> cfg.package != null && cfg.package ? remote_server && cfg.package ? remoteServerExecutableName;
        message = ''
          programs.gram.installRemoteServer requires a non-null programs.gram.package
          with remote_server and remoteServerExecutableName attributes
        '';
      }
    ];

    home.packages = mkIf (cfg.package != null) (
      if cfg.extraPackages != [ ] then
        [
          (pkgs.symlinkJoin {
            name = "${lib.getName cfg.package}-wrapped-${lib.getVersion cfg.package}";
            paths = [ cfg.package ];
            preferLocalBuild = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/${cfg.package.meta.mainProgram or "gram"} \
                --suffix PATH : ${lib.makeBinPath cfg.extraPackages}
            '';
          })
        ]
      else
        [ cfg.package ]
    );

    home.file =
      mkIf
        (
          cfg.installRemoteServer
          && cfg.package != null
          && cfg.package ? remote_server
          && cfg.package ? remoteServerExecutableName
        )
        (
          let
            inherit (cfg.package) remote_server;
            binaryName = cfg.package.remoteServerExecutableName;
          in
          {
            ".gram_server/${binaryName}".source = lib.getExe' remote_server binaryName;
          }
        );

    home.activation = mkMerge [
      (mkIf (cfg.mutableUserSettings && cfg.userSettings != { }) {
        gramSettingsActivation = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          impureConfigMerger "{}" "$dynamic * $static" "${config.xdg.configHome}/gram/settings.jsonc" (
            jsonFormat.generate "gram-user-settings" cfg.userSettings
          )
        );
      })
      (mkIf (cfg.mutableUserKeymaps && cfg.userKeymaps != [ ]) {
        gramKeymapActivation = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          impureConfigMerger "[]"
            "$dynamic + $static | group_by(.context) | map(reduce .[] as $item ({}; . * $item))"
            "${config.xdg.configHome}/gram/keymap.jsonc"
            (jsonFormat.generate "gram-user-keymaps" cfg.userKeymaps)
        );
      })
      (mkIf (cfg.mutableUserTasks && cfg.userTasks != [ ]) {
        gramTasksActivation = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          impureConfigMerger "[]"
            "$dynamic + $static | group_by(.label) | map(reduce .[] as $item ({}; . * $item))"
            "${config.xdg.configHome}/gram/tasks.jsonc"
            (jsonFormat.generate "gram-user-tasks" cfg.userTasks)
        );
      })
      (mkIf (cfg.mutableUserDebug && cfg.userDebug != [ ]) {
        gramDebugActivation = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          impureConfigMerger "[]"
            "$dynamic + $static | group_by(.label) | map(reduce .[] as $item ({}; . * $item))"
            "${config.xdg.configHome}/gram/debug.jsonc"
            (jsonFormat.generate "gram-user-debug" cfg.userDebug)
        );
      })
    ];

    xdg.configFile = mkMerge [
      (lib.mapAttrs' (
        name: value:
        lib.nameValuePair "gram/themes/${name}.json" {
          source =
            if lib.isString value then
              pkgs.writeText "gram-theme-${name}" value
            else if builtins.isPath value || lib.isStorePath value then
              value
            else
              jsonFormat.generate "gram-theme-${name}" value;
        }
      ) cfg.themes)
      (mkIf (!cfg.mutableUserSettings && cfg.userSettings != { }) {
        "gram/settings.jsonc".source = jsonFormat.generate "gram-user-settings" cfg.userSettings;
      })
      (mkIf (!cfg.mutableUserKeymaps && cfg.userKeymaps != [ ]) {
        "gram/keymap.jsonc".source = jsonFormat.generate "gram-user-keymaps" cfg.userKeymaps;
      })
      (mkIf (!cfg.mutableUserTasks && cfg.userTasks != [ ]) {
        "gram/tasks.jsonc".source = jsonFormat.generate "gram-user-tasks" cfg.userTasks;
      })
      (mkIf (!cfg.mutableUserDebug && cfg.userDebug != [ ]) {
        "gram/debug.jsonc".source = jsonFormat.generate "gram-user-debug" cfg.userDebug;
      })
    ];

    home.sessionVariables = mkIf (cfg.defaultEditor && cfg.package != null) editorEnv;
  };
}
