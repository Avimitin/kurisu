{
  config,
  lib,
  pkgs,
  ...
}:
with lib;

let
  cfg = config.kurisu.coding-env;
  myLib = import ../../nix/myLib.nix { inherit config; };
in
{
  imports = [ ];

  options.kurisu.coding-env = {
    enable = mkEnableOption "Configured home as coding env";

    enableLsp = mkEnableOption "Install common used LSP server";

    enableAI = mkEnableOption "Install common used AI stuff";

    configureBash = mkEnableOption "Configure bash";

    extraPackages = mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = [ ];
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        # Misc shell tools
        tmux # terminal multiplxer
        delta # Beautiful git diff
        fd # find alternative
        fzf # fuzzy finder
        ripgrep # grep alternative
        zoxide # cd alternative
        gh # github cli
        nh # Yet-another-Nix-helper
        nix-output-monitor # Pipe nix output for monitor
        just # Just a command executor
      ]
      ++ cfg.extraPackages
      ++ (lib.optionals cfg.enableLsp [
        # Development
        nixfmt # global formatter for all nix sources
        nil # Nix language server
        prettierd # json formatter
        metals # Scala LSP
        ccls # c/cpp LSP
        lua-language-server # Lua LSP
        stylua # Lua formatter
        pyright # Python LSP
        ruff # Python fmt
        uv # Python package manager
        tinymist # Typst LSP w/ preview
      ])
      ++ (lib.optionals cfg.enableAI [
        # AI stuff
        claude-code
        gemini-cli
        opencode
      ]);

    home.file.tmux = myLib.fromDotfile ".tmux.conf";

    programs.bat = {
      enable = true;
      config = {
        theme = "kanagawa";
      };
      themes = {
        kanagawa = {
          src = ../../dotfile/kanagawa.tmTheme;
        };
      };
    };

    home.file.bashrc = mkIf cfg.configureBash {
      enable = true;
      source = pkgs.replaceVarsWith {
        name = "bashrc";

        src = ../../dotfile/.bashrc;

        replacements = {
          bash_completion = pkgs.bash-completion;
        };

        # Ensure .bashrc work and correct
        # postInstall = ''
        #   ${pkgs.buildPackages.bash}/bin/bash -n $target
        #   ${pkgs.shellcheck}/bin/shellcheck -x $target
        # '';
      };
      target = ".bashrc";
    };

    programs.fish = {
      enable = true;
      shellInit = builtins.readFile (
        pkgs.replaceVarsWith {
          name = "config.fish";

          src = ../../dotfile/fish/config.fish;

          replacements = {
            nix_locale_archive = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          };

          postInstall = ''
            ${pkgs.fish}/bin/fish -n "$target"
          '';
        }
      );
      plugins = [
        {
          name = "fishAutoPair";
          src = pkgs.fetchFromGitHub {
            owner = "jorgebucaran";
            repo = "autopair.fish";
            rev = "4d1752ff5b39819ab58d7337c69220342e9de0e2";
            sha256 = "sha256-qt3t1iKRRNuiLWiVoiAYOu+9E7jsyECyIqZJ/oRIT1A=";
          };
        }
      ];
    };

    programs.git = {
      enable = true;
      includes = [
        { path = "~/kurisu/dotfile/git/config"; }
      ];
    };
    # my git status script
    xdg.configFile."git/git-status".source = ../../dotfile/git/git-status;

    programs.fastfetch = {
      enable = true;
      settings = {
        modules = [
          "title"
          "separator"
          "os"
          "host"
          "kernel"
          "uptime"
          "packages"
          "shell"
          "display"
          "de"
          "wm"
          "wmtheme"
          "theme"
          "icons"
          "font"
          "cursor"
          "terminal"
          "terminalfont"
          "cpu"
          "gpu"
          "memory"
          "swap"
          "disk"
          "battery"
          "poweradapter"
          "locale"
          "break"
          "colors"
        ];
      };
    };
  };
}
