{
  config,
  lib,
  pkgs,
  ...
}:
with lib;

let
  cfg = config.kurisu.hm.tools;
  myLib = import ../../nix/myLib.nix { inherit config; };
in
{
  imports = [ ];

  options.kurisu.hm.tools = {
    enable = mkEnableOption "Common sets of tools";

    enableLsp = mkEnableOption "LSP servers";

    enableAI = mkEnableOption "AI editors or CLIs";

    configureBash = mkEnableOption "Bash with configs";

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
        ffmpeg # video processor
        imagemagick # image processor
        mtr # route tracker
        nexttrace # route tracker with world map
        aria2 # better wget
        _7zz # 7z
        lazygit # git TUI
        age # Encryption tool
        sops # Secret management
        dufs # File Share
        git # vcs
        jujutsu # vcs
        jq # json editor
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

    programs = {
      direnv = {
        enable = true;
        enableFishIntegration = true;
        nix-direnv.enable = true;
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

    nix.settings = {
      # Simplify the Nix command line
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      auto-optimise-store = true;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}
