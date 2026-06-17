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

      userSettings = {
        auto_update = false;

        agent = {
          tool_permissions = {
            tools = {
              fetch = {
                default = "allow";
              };
            };
          };
          default_profile = "write";
          default_model = {
            provider = "z.ai";
            model = "glm-5.2";
            enable_thinking = false;
          };
          favorite_models = [ ];
          model_parameters = [ ];
        };

        icon_theme = "Zed (Default)";
        buffer_font_size = 13.0;
        cli_default_open_behavior = "existing_window";
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        vim_mode = true;
        terminal = {
          dock = "left";
          env = {
            TERM = "alacritty";
          };
        };

        language_models = {
          openai_compatible = {
            "z.ai" = {
              api_url = "https://api.z.ai/api/coding/paas/v4";
              available_models = [
                {
                  name = "glm-5.2";
                  max_tokens = 1000000;
                  max_output_tokens = 32000;
                  max_completion_tokens = 200000;
                  capabilities = {
                    tools = true;
                    images = false;
                    parallel_tool_calls = false;
                    prompt_cache_key = false;
                    chat_completions = true;
                    interleaved_reasoning = false;
                  };
                }
              ];
            };
            mimo = {
              api_url = "https://token-plan-cn.xiaomimimo.com/v1";
              available_models = [
                {
                  name = "mimo-v2.5-pro";
                  max_tokens = 1048576;
                  max_output_tokens = 131072;
                  max_completion_tokens = 200000;
                  capabilities = {
                    tools = true;
                    images = false;
                    parallel_tool_calls = false;
                    prompt_cache_key = false;
                    chat_completions = true;
                    interleaved_reasoning = false;
                  };
                }
              ];
            };
          };
        };

        edit_predictions = {
          open_ai_compatible_api = {
            api_url = "https://token-plan-cn.xiaomimimo.com/v1";
          };
        };

        ui_font_family = ".ZedSans";
        ui_font_size = 15.0;
        theme = "Fleet Dark Purple";

        languages = {
          Nix = {
            language_servers = [
              "nil"
              "!nixd"
            ];
          };
        };

        debugger = {
          dock = "left";
        };
        outline_panel = {
          dock = "left";
        };
        collaboration_panel = {
          button = false;
        };
        git_panel = {
          dock = "left";
        };
        project_panel = {
          dock = "left";
        };
      };

      userKeymaps = [
        {
          bindings = {
            "; y" = "editor::CopyFileLocation";
          };
        }
        {
          # `:write` from normal mode
          context = "vim_mode == normal && !menu";
          bindings = {
            "; w" = "workspace::Save";
          };
        }
        {
          # act as Vim ESC (leave insert mode)
          context = "vim_mode == insert && !menu";
          bindings = {
            "alt-;" = "vim::NormalBefore";
          };
        }
        {
          # bash/readline-style movement in insert mode
          context = "vim_mode == insert && !menu";
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
      ];
    };
  };
}
