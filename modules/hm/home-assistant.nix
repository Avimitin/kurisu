# SPDX-License-Identifier: MIT
#
# Adapted for Home Manager from the nixpkgs NixOS Home Assistant module at:
# https://github.com/NixOS/nixpkgs/blob/f4b6996c4e8b9ee06ce147ec344c885f51071b14/nixos/modules/services/home-automation/home-assistant.nix
#
# NixOS-only concerns (system users/groups, firewall rules, device capabilities,
# and system services) are intentionally replaced with a systemd user service.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kurisu.hm.home-assistant;
  yamlFormat = pkgs.formats.yaml { };

  configAttrs = if cfg.config == null then { } else cfg.config;

  # Preserve Home Assistant YAML tags such as `!secret value` and
  # `!include file.yaml`, which pkgs.formats.yaml otherwise quotes.
  renderYAMLFile =
    name: value:
    pkgs.runCommand name
      {
        preferLocalBuilds = true;
      }
      ''
        cp ${yamlFormat.generate name value} "$out"
        sed -i -e "s/'\!\([a-z_]\+\) \(.*\)'/\!\1 \2/;s/^\!\!/\!/;" "$out"
      '';

  usedPlatforms =
    value:
    if lib.isDerivation value then
      [ ]
    else if lib.isAttrs value then
      lib.optionals (value ? platform) [ value.platform ]
      ++ lib.concatMap usedPlatforms (lib.attrValues value)
    else if lib.isList value then
      lib.concatMap usedPlatforms value
    else
      [ ];

  availableComponents = cfg.package.availableComponents;
  explicitComponents = cfg.package.extraComponents or [ ];

  useComponent =
    component:
    lib.hasAttrByPath (lib.splitString "." component) configAttrs
    || builtins.elem component (usedPlatforms configAttrs)
    || builtins.elem component explicitComponents
    || builtins.elem component (
      cfg.extraComponents
      ++ cfg.defaultIntegrations
      ++ map (componentPackage: componentPackage.domain) cfg.customComponents
    );

  selectedComponents = lib.filter useComponent availableComponents;

  finalPackage = cfg.package.override (oldArgs: {
    extraComponents = lib.unique ((oldArgs.extraComponents or [ ]) ++ selectedComponents);
    extraPackages =
      pythonPackages:
      (oldArgs.extraPackages or (_: [ ])) pythonPackages
      ++ cfg.extraPackages pythonPackages
      ++ lib.concatMap (
        componentPackage: componentPackage.propagatedBuildInputs or [ ]
      ) cfg.customComponents;
  });

  customLovelaceModulesDir = pkgs.buildEnv {
    name = "home-assistant-custom-lovelace-modules";
    paths = cfg.customLovelaceModules;
  };

  customLovelaceResources = {
    lovelace.resources = map (card: {
      url = "/local/nix-lovelace-modules/${card.entrypoint or (card.pname + ".js")}?${card.version}";
      type = "module";
    }) cfg.customLovelaceModules;
  };

  themesDir = pkgs.buildEnv {
    name = "home-assistant-themes";
    paths = cfg.themes;
  };

  themesConfig = lib.optionalAttrs (cfg.themes != [ ]) {
    frontend.themes = "!include_dir_merge_named ${themesDir}/themes";
  };

  filteredConfig = lib.converge (lib.filterAttrsRecursive (_: value: value != null)) (
    lib.recursiveUpdate (customLovelaceResources // themesConfig) configAttrs
  );

  configFile =
    if cfg.config == null then null else renderYAMLFile "configuration.yaml" filteredConfig;

  lovelaceConfigFile =
    if cfg.lovelaceConfig != null then
      renderYAMLFile "ui-lovelace.yaml" cfg.lovelaceConfig
    else
      cfg.lovelaceConfigFile;

  blueprintDomains = [
    "automation"
    "script"
    "template"
  ];

  blueprintFilename =
    blueprint:
    let
      name = builtins.baseNameOf (toString blueprint);
    in
    if lib.isStorePath (toString blueprint) then
      builtins.substring 33 (builtins.stringLength name) name
    else
      name;

  installBlueprint =
    domain: blueprint:
    let
      destination = "$config_dir/blueprints/${domain}/${blueprintFilename blueprint}";
    in
    ''
      ln -sfn ${lib.escapeShellArg (toString blueprint)} "${destination}"
    '';

  installBlueprints = lib.concatStrings (
    lib.flatten (lib.mapAttrsToList (domain: map (installBlueprint domain)) cfg.blueprints)
  );

  installCustomComponents = lib.concatMapStringsSep "\n" (componentPackage: ''
    while IFS= read -r -d "" manifest; do
      component_dir="$(dirname "$manifest")"
      ln -sfn "$component_dir" "$config_dir/custom_components/$(basename "$component_dir")"
    done < <(find ${lib.escapeShellArg (toString componentPackage)} -name manifest.json -print0)
  '') cfg.customComponents;

  copyConfig = lib.optionalString (configFile != null) (
    if cfg.configWritable then
      ''
        install -m 0600 ${lib.escapeShellArg (toString configFile)} "$config_dir/configuration.yaml"
      ''
    else
      ''
        ln -sfn ${lib.escapeShellArg (toString configFile)} "$config_dir/configuration.yaml"
      ''
  );

  copyLovelaceConfig = lib.optionalString (lovelaceConfigFile != null) (
    if cfg.lovelaceConfigWritable then
      ''
        install -m 0600 ${lib.escapeShellArg (toString lovelaceConfigFile)} "$config_dir/ui-lovelace.yaml"
      ''
    else
      ''
        ln -sfn ${lib.escapeShellArg (toString lovelaceConfigFile)} "$config_dir/ui-lovelace.yaml"
      ''
  );

  manageCustomLovelaceModules =
    if cfg.customLovelaceModules != [ ] then
      ''
        install -d -m 0700 "$config_dir/www"
        ln -sfn ${lib.escapeShellArg (toString customLovelaceModulesDir)} \
          "$config_dir/www/nix-lovelace-modules"
      ''
    else
      ''
        remove_store_link "$config_dir/www/nix-lovelace-modules"
      '';

  prepareConfig = pkgs.writeShellApplication {
    name = "prepare-home-assistant";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      config_dir=${lib.escapeShellArg cfg.configDir}
      umask 0077

      remove_store_link() {
        local link="$1"
        local target

        if [[ -L "$link" ]]; then
          target="$(readlink "$link")"
          case "$target" in
            "${builtins.storeDir}"/*) rm -f "$link" ;;
          esac
        fi
      }

      install -d -m 0700 \
        "$config_dir" \
        "$config_dir/.cache" \
        "$config_dir/custom_components" \
        "$config_dir/blueprints/automation" \
        "$config_dir/blueprints/script" \
        "$config_dir/blueprints/template"

      ${copyConfig}
      ${copyLovelaceConfig}
      ${manageCustomLovelaceModules}

      while IFS= read -r -d "" component; do
        remove_store_link "$component"
      done < <(find "$config_dir/custom_components" -mindepth 1 -maxdepth 1 -type l -print0)

      ${installCustomComponents}

      while IFS= read -r -d "" blueprint; do
        remove_store_link "$blueprint"
      done < <(find "$config_dir/blueprints" -mindepth 2 -maxdepth 2 -type l -print0)

      ${installBlueprints}
    '';
  };

  escapeSystemdExecArg =
    value:
    let
      stringValue =
        if lib.isString value || lib.isPath value || lib.isDerivation value then
          toString value
        else if lib.isInt value || lib.isFloat value then
          toString value
        else
          throw "escapeSystemdExecArg only accepts strings, paths, numbers, and derivations";
    in
    lib.replaceStrings [ "%" "$" ] [ "%%" "$$" ] (builtins.toJSON stringValue);

  escapeSystemdExecArgs = lib.concatMapStringsSep " " escapeSystemdExecArg;

  automaticRuntimePackages =
    lib.optionals (useComponent "go2rtc") [ pkgs.go2rtc ]
    ++ lib.optionals (useComponent "picotts") [ pkgs.picotts ];

  runtimePackages = automaticRuntimePackages ++ cfg.runtimePackages;
  runtimePath = lib.optionalString (runtimePackages != [ ]) "${lib.makeBinPath runtimePackages}:";

  restartTriggers = [
    finalPackage
    prepareConfig
  ]
  ++ lib.optionals (configFile != null) [ configFile ]
  ++ lib.optionals (lovelaceConfigFile != null) [ lovelaceConfigFile ]
  ++ cfg.customComponents
  ++ cfg.customLovelaceModules
  ++ cfg.themes;
in
{
  options.kurisu.hm.home-assistant = {
    enable = lib.mkEnableOption "Home Assistant as a systemd user service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.home-assistant.overrideAttrs (_: {
        doInstallCheck = false;
      });
      defaultText = lib.literalExpression ''
        pkgs.home-assistant.overrideAttrs (_: {
          doInstallCheck = false;
        })
      '';
      description = "Base Home Assistant package.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      default = finalPackage;
      internal = true;
      readOnly = true;
      description = "Home Assistant package with the selected integration dependencies.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/home-assistant";
      defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/home-assistant"'';
      description = ''
        Mutable Home Assistant configuration and state directory. This directory
        contains authentication data, integration tokens, and the recorder database.
      '';
    };

    config = lib.mkOption {
      type = lib.types.nullOr yamlFormat.type;
      default = null;
      example = lib.literalExpression ''
        {
          default_config = { };
          homeassistant = {
            name = "Home";
            time_zone = "Etc/UTC";
            unit_system = "metric";
          };
        }
      '';
      description = ''
        Declarative configuration.yaml contents. YAML tags such as
        `!secret latitude` and `!include automations.yaml` are supported.
        Set this to null to let Home Assistant manage configuration.yaml.
      '';
    };

    configWritable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Copy the declarative configuration.yaml to the mutable state directory
        instead of linking it read-only. The copy is replaced on every service start.
      '';
    };

    defaultIntegrations = lib.mkOption {
      type = lib.types.listOf (lib.types.enum availableComponents);
      default = [
        "application_credentials"
        "frontend"
        "hardware"
        "logger"
        "network"
        "system_health"
        "automation"
        "person"
        "scene"
        "script"
        "tag"
        "zone"
        "counter"
        "input_boolean"
        "input_button"
        "input_datetime"
        "input_number"
        "input_select"
        "input_text"
        "schedule"
        "timer"
        "backup"
      ];
      readOnly = true;
      description = "Integrations Home Assistant always requires during normal startup.";
    };

    extraComponents = lib.mkOption {
      type = lib.types.listOf (lib.types.enum availableComponents);
      default = [
        "default_config"
        "met"
        "esphome"
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isAarch [ "rpi_power" ];
      description = ''
        Built-in Home Assistant integrations whose Python dependencies should be
        included in the package.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      defaultText = lib.literalExpression "pythonPackages: [ ]";
      description = "Additional Python packages available to Home Assistant.";
    };

    customComponents = lib.mkOption {
      type = lib.types.listOf (
        lib.types.addCheck lib.types.package (package: package.isHomeAssistantComponent or false)
        // {
          name = "home-assistant-component";
          description = "Home Assistant custom component package";
        }
      );
      default = [ ];
      description = "Custom component packages linked into custom_components.";
    };

    customLovelaceModules = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Custom Lovelace module packages exposed below /local/nix-lovelace-modules/.";
    };

    themes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.addCheck lib.types.package (package: package.isHomeAssistantTheme or false)
        // {
          name = "home-assistant-theme";
          description = "Home Assistant theme package";
        }
      );
      default = [ ];
      description = "Home Assistant theme packages.";
    };

    lovelaceConfig = lib.mkOption {
      type = lib.types.nullOr yamlFormat.type;
      default = null;
      description = "Declarative ui-lovelace.yaml contents.";
    };

    lovelaceConfigFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Existing ui-lovelace.yaml file to install.";
    };

    lovelaceConfigWritable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Copy ui-lovelace.yaml instead of linking it read-only. The copy is
        replaced on every service start.
      '';
    };

    blueprints = lib.genAttrs blueprintDomains (
      domain:
      lib.mkOption {
        type = lib.types.listOf (lib.types.coercedTo lib.types.path toString lib.types.pathInStore);
        default = [ ];
        description = "${domain} blueprints to install declaratively.";
      }
    );

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--debug" ];
      description = "Extra arguments passed to hass.";
    };

    runtimePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional command-line programs placed in the service PATH.";
    };

    writablePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional paths that the hardened service may write. Add paths here when
        an integration needs to write outside configDir.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra service environment variables. Do not put secrets here because
        systemd unit files are world-readable in the Nix store.
      '';
    };

    systemdTarget = lib.mkOption {
      type = lib.types.str;
      default = "default.target";
      description = "User systemd target that should start Home Assistant.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "kurisu.hm.home-assistant" pkgs lib.platforms.linux)
      {
        assertion = lib.hasPrefix "/" cfg.configDir;
        message = "kurisu.hm.home-assistant.configDir must be an absolute path.";
      }
      {
        assertion = !(cfg.lovelaceConfig != null && cfg.lovelaceConfigFile != null);
        message = "Only one of lovelaceConfig or lovelaceConfigFile may be set.";
      }
      {
        assertion = cfg.themes == [ ] || !(lib.hasAttrByPath [ "frontend" "themes" ] configAttrs);
        message = "themes and config.frontend.themes cannot both be set.";
      }
    ];

    home.packages = [ finalPackage ];

    home.activation.createHomeAssistantStateDirectory =
      lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
        ''
          run ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 ${lib.escapeShellArg cfg.configDir}
        '';

    systemd.user.services.home-assistant = {
      Unit = {
        Description = "Home Assistant";
        Documentation = [ "https://www.home-assistant.io/docs/" ];
        After = [ "network-online.target" ];
        X-Restart-Triggers = restartTriggers;
      };

      Service = {
        Type = "simple";
        ExecStartPre = lib.getExe prepareConfig;
        ExecStart = escapeSystemdExecArgs (
          [
            (lib.getExe finalPackage)
            "--config"
            cfg.configDir
          ]
          ++ cfg.extraArgs
        );
        ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
        WorkingDirectory = cfg.configDir;
        Restart = "on-failure";
        RestartSec = 5;
        RestartForceExitStatus = 100;
        SuccessExitStatus = 100;
        KillSignal = "SIGINT";
        Environment = [
          "HOME=${cfg.configDir}"
          "PYTHONPATH=${finalPackage.pythonPath}"
          "PATH=${runtimePath}/usr/local/bin:/usr/bin:/bin"
          "XDG_CACHE_HOME=${cfg.configDir}/.cache"
        ]
        ++ lib.mapAttrsToList (name: value: "${name}=${value}") cfg.environment;

        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.configDir ] ++ cfg.writablePaths;
        RestrictAddressFamilies = [
          "AF_BLUETOOTH"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_PACKET"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };

      Install.WantedBy = [ cfg.systemdTarget ];
    };
  };
}
