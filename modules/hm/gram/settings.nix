{
  buffer_font_size = 13;
  debugger.dock = "left";
  diagnostics.inline.enabled = true;
  format_on_save = "on";
  git.inline_blame.enabled = false;
  git_panel.dock = "left";
  icon_theme = "Gram (Default)";
  indent_guides.background_coloring = "disabled";
  inlay_hints.enabled = true;
  languages.Nix.language_servers = [
    "nil"
    "!nixd"
  ];
  load_direnv = "shell_hook";
  lsp.tinymist = {
    initialization_options.preview.background.enabled = true;
    settings = {
      exportPdf = "onSave";
      formatterMode = "typstyle";
      outputPath = "$root/$name";
    };
  };
  minimap.show = "never";
  outline_panel.dock = "left";
  project_panel.dock = "left";
  relative_line_numbers = "wrapped";
  show_whitespaces = "trailing";
  soft_wrap = "prefer_line";
  tab_size = 2;
  terminal = {
    dock = "left";
    env.TERM = "alacritty";
  };
  text_rendering_mode = "platform_default";
  theme = "Gram Dark";
  title_bar.show_user_picture = false;
  ui_font_family = ".GramSans";
  ui_font_size = 15;
  vim_mode = true;
  which_key.enabled = true;
}
