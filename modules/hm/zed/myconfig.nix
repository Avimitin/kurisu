{
  config,
  lib,
  pkgs,
  ...
}:
let
  profileCfg = config.kurisu.hm.zed;

  # Keep this policy outside the synchronized settings file so regenerating
  # settings.nix can never restore Zed's download/install capabilities.
  downloadPolicy = {
    auto_install_extensions = {
      html = false;
      pathy = false;
    };

    auto_update_extensions = {
      "catppuccin-icons" = false;
      "fleet-themes" = false;
      fish = false;
      nix = false;
      scala = false;
      typst = false;
      pathy = false;
    };

    granted_extension_capabilities = [
      {
        kind = "process:exec";
        command = "*";
        args = [ "**" ];
      }
    ];
  };

  # Pathy is installed declaratively from the nix store; never let Zed
  # download/update the extension or fetch its sidecar server from GitHub
  # at runtime. `server_path` takes precedence over any download logic.
  syncedSettings = import ./settings.nix;

  # Insert pathy right after the primary server of a language whose
  # `language_servers` list is pinned in settings.nix. Languages without an
  # explicit list pick pathy up automatically: the extension manifest
  # registers it for them and Zed's default `["..."]` enables all
  # registered servers.
  withPathy =
    servers:
    let
      without = builtins.filter (name: name != "pathy") servers;
    in
    if without == [ ] then
      [
        "..."
        "pathy"
      ]
    else
      lib.take 1 without ++ [ "pathy" ] ++ lib.drop 1 without;

  pathySettings = {
    languages = {
      Python.language_servers = withPathy (syncedSettings.languages.Python.language_servers or [ ]);
      Nix.language_servers = withPathy (syncedSettings.languages.Nix.language_servers or [ ]);
    };

    lsp.pathy.settings = {
      auto_download = false;
      server_path = lib.getExe' pkgs.pathy-server "pathy-server";
    };
  };
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf profileCfg.enable {
    programs = {
      zed-editor = {
        enable = true;
        defaultEditor = true;

        # Regenerate the synchronized portion from Zed's live settings with
        # ./sync.sh. The download policy above always wins over synchronized
        # values and over mutable settings already present on the machine.
        userSettings = lib.recursiveUpdate (syncedSettings // downloadPolicy) pathySettings;

        userKeymaps = [
          {
            # Reset the layout to the editor with only the file tree dock open,
            # or open the Agent panel full-screen. The F23/F24 bindings are
            # internal steps used by SendKeystrokes so focus settles before zoom.
            context = "Workspace";
            bindings = {
              f23 = "agent::FocusAgent";
              f24 = "workspace::ToggleZoom";
              "ctrl-alt-1" = [
                "action::Sequence"
                [
                  "workspace::CloseAllDocks"
                  "project_panel::ToggleFocus"
                ]
              ];
              "ctrl-alt-2" = [
                "workspace::SendKeystrokes"
                "f23 f24"
              ];
              "alt-g g" = [
                "task::Spawn"
                {
                  task_name = "Lazygit";
                  reveal_target = "center";
                }
              ];
            };
          }
          {
            # A hidden panel retains its zoom state, so leave full-screen Agent
            # mode before closing it. Repeated Ctrl-Alt-2 stays full-screen.
            context = "AgentPanel";
            bindings = {
              "ctrl-alt-1" = [
                "action::Sequence"
                [
                  "workspace::ToggleZoom"
                  "workspace::CloseAllDocks"
                  "project_panel::ToggleFocus"
                ]
              ];
              "ctrl-alt-2" = "agent::FocusAgent";
            };
          }
          {
            context = "(vim_mode == normal || vim_mode == visual) && !menu";
            bindings = {
              s = "vim::PushFlash";
              "; y" = "editor::CopyFileLocation";
              "shift-l" = [
                "vim::EndOfLine"
                { display_lines = true; }
              ];
              "shift-h" = [
                "vim::FirstNonWhitespace"
                { display_lines = true; }
              ];
            };
          }
          {
            # Keep the default `g s` (outline toggle) from firing in every
            # Vim command mode. It is re-added in normal mode below so that
            # visual mode keeps `g s` for surrounds.
            context = "VimControl && !menu";
            unbind = {
              "g s" = "outline::Toggle";
            };
          }
          {
            context = "vim_mode == normal && !menu";
            bindings = {
              "g s" = "outline::Toggle";
              "; w" = "workspace::Save";
            };
          }
          {
            context = "Terminal";
            bindings =
              let
                kmap = k: [
                  "terminal::SendKeystroke"
                  k
                ];
                bypass = ks: ks |> map (k: lib.nameValuePair k (kmap k)) |> lib.listToAttrs;
              in
              bypass [
                "ctrl-p"
                "ctrl-n"
              ];
          }
          {
            context = "vim_mode == normal || Dock";
            bindings = {
              "alt-k" = "workspace::ActivatePaneUp";
              "alt-j" = "workspace::ActivatePaneDown";
            };
          }
          {
            context = "vim_mode == normal || Workspace || Dock";
            bindings = {
              "alt-l" = "workspace::ActivatePaneRight";
              "alt-h" = "workspace::ActivatePaneLeft";
              # Next/previous tab, like gt / gT.
              "alt-n" = "vim::GoToTab";
              "alt-p" = "vim::GoToPreviousTab";
            };
          }
          {
            context = "vim_mode == visual && !menu";
            bindings."g s" = "vim::PushAddSurrounds";
          }
          {
            # Readline/bash-style editing in Vim insert mode. Zed's Linux
            # defaults use several of these keys for Vim insert commands
            # (Ctrl-K opens the digraph prompt, Ctrl-E copies the line below,
            # ...), so shadow them only while inserting. Ctrl-P/Ctrl-N are
            # left alone because Vim uses them for word completion, and
            # Ctrl-V/Ctrl-R/Ctrl-O keep their Vim meanings.
            context = "vim_mode == insert && !menu";
            bindings = {
              # Cursor movement.
              "ctrl-a" = [
                "editor::MoveToBeginningOfLine"
                { stop_at_soft_wraps = false; }
              ];
              "ctrl-e" = [
                "editor::MoveToEndOfLine"
                { stop_at_soft_wraps = false; }
              ];
              "ctrl-b" = "editor::MoveLeft";
              "ctrl-f" = "editor::MoveRight";
              "alt-b" = "editor::MoveToPreviousWordStart";
              "alt-f" = "editor::MoveToNextWordEnd";

              # Character and word editing.
              "ctrl-d" = "editor::Delete";
              "ctrl-h" = "editor::Backspace";
              "ctrl-w" = [
                "editor::DeleteToPreviousWordStart"
                {
                  ignore_newlines = false;
                  ignore_brackets = false;
                }
              ];
              "alt-backspace" = [
                "editor::DeleteToPreviousWordStart"
                {
                  ignore_newlines = false;
                  ignore_brackets = false;
                }
              ];
              "alt-d" = [
                "editor::DeleteToNextWordEnd"
                {
                  ignore_newlines = false;
                  ignore_brackets = false;
                }
              ];

              # Line editing. Zed has no cut-to-beginning-of-line action,
              # so Ctrl-U deletes without populating the kill ring.
              "ctrl-k" = "editor::KillRingCut";
              "ctrl-u" = "editor::DeleteToBeginningOfLine";
            };
          }
        ];
      };

      zed-editor-extensions = {
        enable = true;
        packages = with pkgs.zed-extensions-path-only; [
          catppuccin-icons
          fleet-themes
          fish
          nix
          scala
          typst
          make
          pathy
          elixir
        ];
      };
    };
  };
}
