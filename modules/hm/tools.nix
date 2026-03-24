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

    configureZsh = mkEnableOption "Zsh with configs";

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
        eza # ls replacement
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
        enableZshIntegration = cfg.configureZsh;
        nix-direnv.enable = true;
      };

      zoxide = {
        enable = true;
        enableFishIntegration = false;
        enableZshIntegration = cfg.configureZsh;
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

    programs.zsh = mkIf cfg.configureZsh {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = {
        rm = "rm -i";
        ll = "eza -alh --color=always --icons=always --hyperlink --group-directories-first";
        rsyncz = "rsync -aczvhPL";
        rsynca = "rsync -avhP";
        ssh = "TERM=xterm-256color ssh";
        tmuxd = "systemd-run --user --scope tmux new-session";
        tl = "tmux ls";
        ta = "tmux attach-session -t";
        userctl = "systemctl --user";
        ip = "ip -c";
      };

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/zsh_history";
        ignoreDups = true;
        share = true;
      };

      initContent = lib.mkMerge [
        (lib.mkBefore ''
          # Ensure history directory exists
          mkdir -p "${config.xdg.dataHome}/zsh"

          if [[ -o login ]]; then
            export QT_QPA_PLATFORM="wayland;xcb"
            export QT_QPA_PLATFORMTHEME="qt6ct"
            export MOZ_ENABLE_WAYLAND=1
          fi
        '')

        (lib.mkOrder 1000 ''
          # Path
          path+=("$HOME/.nix-profile/bin")

          # SSH Agent
          export MY_SSH_AGENT_ENV="$HOME/.ssh/agent_env"
          __start_agent() {
              (umask 077; ssh-agent -s | sed 's/^echo/#echo/' > "$MY_SSH_AGENT_ENV")
              source "$MY_SSH_AGENT_ENV" > /dev/null
          }

          if [[ -f "$MY_SSH_AGENT_ENV" ]]; then
              source "$MY_SSH_AGENT_ENV" > /dev/null
              if [[ -z "$SSH_AGENT_PID" ]] || ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
                  __start_agent
              fi
          else
              __start_agent
          fi

          # Editor & Manpager
          if command -v nvim >/dev/null 2>&1; then
              alias vi='nvim'
              export EDITOR='nvim'
              export MANPAGER='nvim +Man!'
          elif command -v vim >/dev/null 2>&1; then
              alias vi='vim'
              export EDITOR='vim'
              export MANPAGER='vim +Man!'
          fi

          if [[ -n "$EDITOR" ]]; then
              export VISUAL="$EDITOR"
          fi
          export SYSTEMD_EDITOR="$EDITOR"

          # GPG
          if command -v gpg >/dev/null 2>&1; then
              export GPG_TTY=$(tty)
          fi

          # Locale
          if [[ -r "${pkgs.glibcLocales}/lib/locale/locale-archive" ]]; then
              export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
          elif [[ -r /usr/lib/locale/locale-archive ]]; then
              export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive
          fi

          # XDG & Misc
          export XDG_CONFIG_HOME="$HOME/.config"
          export XDG_CACHE_HOME="$HOME/.cache"
          export XDG_DATA_HOME="$HOME/.local/share"
          export CLICOLOR=1
          export PAGER='less -R'
          export FZF_DEFAULT_OPTS='--height 35% --layout=reverse'

          # PS1
          PROMPT='%2~ %(?.%F{green}>.%F{red}>)%f '
        '')
      ];
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
