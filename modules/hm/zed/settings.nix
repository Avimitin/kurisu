{
  active_pane_modifiers = {
    inactive_opacity = 0.7;
  };
  agent = {
    default_profile = "write";
    dock = "right";
    enable_feedback = false;
    favorite_models = [ ];
    model_parameters = [ ];
  };
  auto_install_extensions = {
    html = false;
    pathy = false;
  };
  auto_update = false;
  auto_update_extensions = {
    catppuccin-icons = false;
    fish = false;
    fleet-themes = false;
    nix = false;
    pathy = false;
    scala = false;
    typst = false;
  };
  buffer_font_fallbacks = [ "Noto Sans Mono CJK SC" ];
  buffer_font_family = "IoskeleyMono Nerd Font";
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
  format_on_save = "on";
  git = {
    inline_blame = {
      enabled = false;
    };
  };
  git_panel = {
    dock = "left";
  };
  granted_extension_capabilities = [
    {
      args = [ "**" ];
      command = "*";
      kind = "process:exec";
    }
  ];
  icon_theme = {
    dark = "Catppuccin Macchiato";
    light = "Catppuccin Macchiato";
    mode = "dark";
  };
  indent_guides = {
    background_coloring = "disabled";
  };
  inlay_hints = {
    enabled = true;
  };
  languages = {
    Bash = {
      enable_language_server = false;
    };
    "C++" = {
      document_symbols = "on";
      inlay_hints = {
        enabled = true;
        show_background = false;
      };
    };
    CSS = {
      enable_language_server = false;
    };
    Json = {
      enable_language_server = false;
    };
    Nix = {
      language_servers = [
        "nil"
        "pathy"
        "!nixd"
      ];
    };
    Python = {
      language_servers = [
        "ty"
        "pathy"
        "!basedpyright"
      ];
    };
    YAML = {
      enable_language_server = false;
    };
  };
  load_direnv = "shell_hook";
  lsp = {
    pathy = {
      settings = {
        auto_download = false;
        server_path = "/nix/store/vgdjf6gsyahfx26amsrr77gkakfqmk96-pathy-server-0.2.0/bin/pathy-server";
      };
    };
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
  theme = {
    dark = "Fleet Dark Purple";
    light = "One Light";
    mode = "dark";
  };
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
