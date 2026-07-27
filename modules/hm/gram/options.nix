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

  mkExtensionTree =
    extensions:
    pkgs.runCommand "gram-extensions"
      {
        nativeBuildInputs = [ pkgs.python3 ];
        extensionPackages = builtins.toJSON (map (package: toString package) extensions);
        passAsFile = [ "extensionPackages" ];
      }
      ''
        python3 <<'PY'
        import json
        import os
        from pathlib import Path
        import re
        import sys
        import tomllib

        packages = json.loads(Path(os.environ["extensionPackagesPath"]).read_text())
        output = Path(os.environ["out"])
        output.mkdir()
        installed = {}

        def fail(message):
            print(f"gram extension validation failed: {message}", file=sys.stderr)
            raise SystemExit(1)

        def api_version(value, manifest_path):
            if not isinstance(value, str):
                fail(f"{manifest_path}: lib.version must be a semantic-version string")
            match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:[-+][0-9A-Za-z.-]+)?", value)
            if match is None:
                fail(f"{manifest_path}: invalid lib.version {value!r}")
            return tuple(map(int, match.groups()))

        for package in packages:
            extensions_dir = Path(package) / "share" / "zed" / "extensions"
            if not extensions_dir.is_dir():
                fail(f"{package} does not contain share/zed/extensions")

            extension_dirs = sorted(extensions_dir.iterdir())
            if not extension_dirs:
                fail(f"{extensions_dir} contains no extensions")

            for extension_dir in extension_dirs:
                if not extension_dir.is_dir():
                    fail(f"{extension_dir} is not an extension directory")

                manifest_path = extension_dir / "extension.toml"
                if not manifest_path.is_file():
                    fail(f"{extension_dir} does not contain extension.toml")

                try:
                    with manifest_path.open("rb") as manifest_file:
                        manifest = tomllib.load(manifest_file)
                except (OSError, tomllib.TOMLDecodeError) as error:
                    fail(f"could not parse {manifest_path}: {error}")

                extension_id = manifest.get("id")
                if not isinstance(extension_id, str) or not extension_id:
                    fail(f"{manifest_path}: id must be a non-empty string")
                if extension_id != extension_dir.name:
                    fail(
                        f"{manifest_path}: manifest id {extension_id!r} does not match "
                        f"directory name {extension_dir.name!r}"
                    )

                schema_version = manifest.get("schema_version")
                if (
                    isinstance(schema_version, bool)
                    or not isinstance(schema_version, int)
                    or not 0 <= schema_version <= 1
                ):
                    fail(f"{manifest_path}: schema_version must be an integer from 0 through 1")

                wasm_path = extension_dir / "extension.wasm"
                if wasm_path.is_file():
                    lib = manifest.get("lib")
                    if not isinstance(lib, dict) or "version" not in lib:
                        fail(f"{manifest_path}: extension.wasm requires lib.version")
                    version = api_version(lib["version"], manifest_path)
                    if version > (0, 7, 0):
                        fail(f"{manifest_path}: unsupported lib.version {lib['version']!r}; Gram 3.2 supports up to 0.7.0")

                previous = installed.get(extension_id)
                if previous is not None:
                    fail(f"duplicate extension id {extension_id!r}: {previous} and {extension_dir}")
                installed[extension_id] = extension_dir
                os.symlink(extension_dir, output / extension_id)
        PY
      '';

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

    extensions = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.zed-extensions.nix ]";
      description = ''
        Extension packages to install. Each package may provide one or more
        extensions below share/zed/extensions/<extension-id>.
      '';
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

    # Keep Gram's PATH untouched: language servers come from the launching
    # environment (including a project's direnv/devShell), never its package.
    home.packages = mkIf (cfg.package != null) [ cfg.package ];

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

    xdg.dataFile = mkIf (cfg.extensions != [ ]) {
      "gram/extensions/installed" = {
        source = mkExtensionTree cfg.extensions;
        recursive = true;
      };
    };

    home.sessionVariables = mkIf (cfg.defaultEditor && cfg.package != null) editorEnv;
  };
}
