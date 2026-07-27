{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.kurisu.hm.zed;
in
{
  options.kurisu.hm.zed = {
    enable = mkEnableOption "Zed editor with declarative configuration";
  };

  config = mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;

      # Settings are generated from Zed's live ~/.config/zed/settings.json by
      # ./zed/sync.sh, which strips machine-local keys listed in
      # ./zed/blacklist.json (e.g. ssh_connections) and materialises the rest
      # as Nix via `nix-instantiate --eval --strict`. Edit settings in Zed, then
      # re-run the script to regenerate this file.
      userSettings = import ./zed/settings.nix;

      userKeymaps = [
        {
          context = "(VimControl && (vim_mode == normal || vim_mode == visual)) && !menu";
          bindings = {
            "; y" = "editor::CopyFileLocation";
          };
        }
        {
          # `:write` from normal mode
          context = "(VimControl && vim_mode == normal) && !menu";
          bindings = {
            "; w" = "workspace::Save";
          };
        }
        {
          # act as Vim ESC (leave insert mode)
          context = "(VimControl && vim_mode == insert) && !menu";
          bindings = {
            "alt-;" = "vim::NormalBefore";
          };
        }
        {
          # bash/readline-style movement in insert mode
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
          bindings = {
            "alt-k" = "workspace::ActivatePaneUp";
          };
        }
        {
          context = "(VimControl && vim_mode == normal) || Dock";
          bindings = {
            "alt-j" = "workspace::ActivatePaneDown";
          };
        }
        {
          context = "(VimControl && vim_mode == normal) || Workspace || Dock";
          bindings = {
            "alt-l" = "workspace::ActivatePaneRight";
          };
        }
        {
          context = "(VimControl && vim_mode == normal) || Workspace || Dock";
          bindings = {
            "alt-h" = "workspace::ActivatePaneLeft";
          };
        }
        {
          # next/previous tab, like gt / gT
          context = "(VimControl && vim_mode == normal) || Workspace || Dock";
          bindings = {
            "alt-n" = "vim::GoToTab";
            "alt-p" = "vim::GoToPreviousTab";
          };
        }
        {
          context = "(vim_mode == normal || vim_mode == visual) && !menu";
          bindings = {
            "s" = "vim::HelixJumpToWord";
          };
        }
        {
          context = "vim_mode == visual && !menu";
          bindings = {
            "g s" = "vim::PushAddSurrounds";
          };
        }
        {
          context = "VimControl && vim_mode == normal && !menu";
          bindings = {
            "shift-l" = [
              "vim::EndOfLine"
              { display_lines = true; }
            ];
          };
        }
        {
          context = "(VimControl && vim_mode == normal) && !menu";
          bindings = {
            "shift-h" = [
              "vim::FirstNonWhitespace"
              { display_lines = true; }
            ];
          };
        }
      ];
    };
  };
}
