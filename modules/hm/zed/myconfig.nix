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
    };

    auto_update_extensions = {
      "catppuccin-icons" = false;
      "fleet-themes" = false;
      fish = false;
      nix = false;
      scala = false;
      typst = false;
    };

    granted_extension_capabilities = [
      {
        kind = "process:exec";
        command = "*";
        args = [ "**" ];
      }
    ];
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
        userSettings = (import ./settings.nix) // downloadPolicy;

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
            context = "VimControl && (vim_mode == normal || vim_mode == visual) && !menu";
            bindings."; y" = "editor::CopyFileLocation";
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
            # `:write` from normal mode.
            context = "VimControl && vim_mode == normal && !menu";
            bindings."; w" = "workspace::Save";
          }
          {
            # Act as Vim ESC (leave insert mode).
            context = "(VimControl && vim_mode == insert) && !menu";
            bindings."alt-;" = "vim::NormalBefore";
          }
          {
            # Bash/readline-style movement in insert mode.
            context = "(VimControl && vim_mode == insert) && !menu";
            bindings = {
              "ctrl-a" = [
                "editor::MoveToBeginningOfLine"
                { stop_at_indent = true; }
              ];
              "ctrl-e" = "editor::MoveToEndOfLine";
              "alt-b" = "editor::MoveToPreviousWordStart";
              "alt-f" = "editor::MoveToNextWordEnd";
              "ctrl-d" = "editor::Delete";
              "alt-d" = "editor::DeleteToNextWordEnd";
            };
          }
          {
            context = "(VimControl && vim_mode == normal) || Dock";
            bindings."alt-k" = "workspace::ActivatePaneUp";
          }
          {
            context = "(VimControl && vim_mode == normal) || Dock";
            bindings."alt-j" = "workspace::ActivatePaneDown";
          }
          {
            context = "(VimControl && vim_mode == normal) || Workspace || Dock";
            bindings."alt-l" = "workspace::ActivatePaneRight";
          }
          {
            context = "(VimControl && vim_mode == normal) || Workspace || Dock";
            bindings."alt-h" = "workspace::ActivatePaneLeft";
          }
          {
            # Next/previous tab, like gt / gT.
            context = "(VimControl && vim_mode == normal) || Workspace || Dock";
            bindings = {
              "alt-n" = "vim::GoToTab";
              "alt-p" = "vim::GoToPreviousTab";
            };
          }
          {
            context = "(vim_mode == normal || vim_mode == visual) && !menu";
            bindings.s = "vim::HelixJumpToWord";
          }
          {
            context = "vim_mode == visual && !menu";
            bindings."g s" = "vim::PushAddSurrounds";
          }
          {
            context = "VimControl && (vim_mode == normal || vim_mode == visual) && !menu";
            bindings."shift-l" = [
              "vim::EndOfLine"
              { display_lines = true; }
            ];
          }
          {
            context = "VimControl && (vim_mode == normal || vim_mode == visual) && !menu";
            bindings."shift-h" = [
              "vim::FirstNonWhitespace"
              { display_lines = true; }
            ];
          }
          {
            context = "Workspace";
            bindings."alt-g g" = [
              "task::Spawn"
              {
                task_name = "Lazygit";
                reveal_target = "center";
              }
            ];
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
        ];
      };
    };
  };
}
