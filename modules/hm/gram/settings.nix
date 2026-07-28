{
  active_pane_modifiers = {
    inactive_opacity = 0.7;
  };
  buffer_font_family = "SF Mono";
  buffer_font_size = 13;
  buffer_font_weight = 400;
  buffer_line_height = "standard";
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
  icon_theme = "Catppuccin Macchiato";
  indent_guides = {
    background_coloring = "disabled";
  };
  inlay_hints = {
    enabled = true;
  };
  languages = {
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
    Json = {
      enable_language_server = false;
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
  relative_line_numbers = "wrapped";
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
  terminal = {
    dock = "left";
    env = {
      TERM = "alacritty";
    };
  };
  text_rendering_mode = "platform_default";
  theme = "Gleam Dark";
  title_bar = {
    show = false;
    show_user_picture = false;
  };
  ui_font_family = "SF Pro Rounded";
  ui_font_size = 15;
  vim_mode = true;
  which_key = {
    enabled = true;
  };
}
