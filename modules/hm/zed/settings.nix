{
  active_pane_modifiers = {
    inactive_opacity = 0.7;
  };
  agent = {
    default_model = {
      effort = "xhigh";
      enable_thinking = false;
      model = "glm-5.2";
      provider = "z.ai";
    };
    default_profile = "write";
    dock = "right";
    enable_feedback = false;
    favorite_models = [ ];
    model_parameters = [ ];
  };
  auto_update = false;
  buffer_font_family = "SF Mono";
  buffer_font_size = 13;
  buffer_font_weight = 400;
  buffer_line_height = "standard";
  cli_default_open_behavior = "existing_window";
  collaboration_panel = {
    button = false;
  };
  debugger = {
    dock = "left";
  };
  diagnostics = {
    inline = {
      enabled = true;
    };
  };
  edit_predictions = {
    mode = "subtle";
    open_ai_compatible_api = {
      api_url = "https://token-plan-cn.xiaomimimo.com/v1";
      model = "glm-4.7";
      prompt_format = "glm";
    };
    provider = "open_ai_compatible_api";
  };
  format_on_save = "on";
  git = {
    inline_blame = {
      enabled = false;
    };
  };
  git_panel = {
    dock = "left";
  };
  icon_theme = "Catppuccin Macchiato";
  indent_guides = {
    background_coloring = "disabled";
  };
  inlay_hints = {
    enabled = true;
  };
  language_models = {
    openai_compatible = {
      mimo = {
        api_url = "https://token-plan-cn.xiaomimimo.com/v1";
        available_models = [
          {
            capabilities = {
              chat_completions = true;
              images = false;
              interleaved_reasoning = false;
              parallel_tool_calls = false;
              prompt_cache_key = false;
              tools = true;
            };
            max_completion_tokens = 200000;
            max_output_tokens = 131072;
            max_tokens = 1048576;
            name = "mimo-v2.5-pro";
          }
        ];
      };
      "z.ai" = {
        api_url = "https://api.z.ai/api/coding/paas/v4";
        available_models = [
          {
            capabilities = {
              chat_completions = true;
              images = false;
              interleaved_reasoning = false;
              parallel_tool_calls = false;
              prompt_cache_key = false;
              tools = true;
            };
            max_completion_tokens = 200000;
            max_output_tokens = 32000;
            max_tokens = 1000000;
            name = "glm-5.2";
          }
        ];
      };
    };
  };
  languages = {
    Bash = {
      enable_language_server = false;
    };
    Json = {
      enable_language_server = false;
    };
    Nix = {
      language_servers = [
        "nil"
        "!nixd"
      ];
    };
    Python = {
      language_servers = [
        "ty"
        "!basedpyright"
      ];
    };
  };
  load_direnv = "shell_hook";
  lsp = {
    tinymist = {
      initialization_options = {
        preview = {
          background = {
            enabled = true;
          };
        };
      };
      settings = {
        exportPdf = "onSave";
        formatterMode = "typstyle";
        outputPath = "$root/$name";
      };
    };
  };
  minimap = {
    show = "never";
  };
  outline_panel = {
    dock = "left";
  };
  project_panel = {
    dock = "left";
    file_icons = true;
    folder_icons = true;
  };
  proxy = "";
  relative_line_numbers = "wrapped";
  semantic_tokens = "combined";
  show_whitespaces = "trailing";
  soft_wrap = "prefer_line";
  status_bar = {
    icon_size = "default";
    show = true;
  };
  tab_size = 2;
  tabs = {
    file_icons = true;
    git_status = true;
  };
  telemetry = {
    diagnostics = false;
    metrics = false;
  };
  terminal = {
    dock = "left";
    env = {
      TERM = "alacritty";
    };
  };
  text_rendering_mode = "platform_default";
  theme = "Fleet Dark Purple";
  title_bar = {
    show = false;
    show_sign_in = false;
    show_user_menu = false;
    show_user_picture = false;
  };
  ui_font_family = "SF Pro Rounded";
  ui_font_size = 15;
  vim_mode = true;
  which_key = {
    enabled = true;
  };
}
