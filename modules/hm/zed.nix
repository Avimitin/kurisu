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
            provider = "mimo";
            model = "mimo-v2.5-pro";
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
          env = {
            TERM = "alacritty";
          };
        };

        language_models = {
          openai_compatible = {
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
      };
    };
  };
}
