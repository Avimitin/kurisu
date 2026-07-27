{
  config,
  lib,
  pkgs,
  ...
}:
let
  profileCfg = config.kurisu.hm.gram;
in
{
  imports = [ ./options.nix ];

  options.kurisu.hm.gram.enable =
    lib.mkEnableOption "Gram with this repository's declarative configuration";

  config = lib.mkIf profileCfg.enable {
    programs.gram = {
      enable = true;

      # Regenerate this from Gram's live settings with ./sync.sh.
      userSettings = import ./settings.nix;

      extensions = with pkgs.gram-extensions; [
        fish
        scala
        typst
      ];

      userKeymaps = [
        {
          context = "(VimControl && (vim_mode == normal || vim_mode == visual)) && !menu";
          bindings."; y" = "editor::CopyFileLocation";
        }
        {
          # `:write` from normal mode.
          context = "(VimControl && vim_mode == normal) && !menu";
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
      ];
    };
  };
}
