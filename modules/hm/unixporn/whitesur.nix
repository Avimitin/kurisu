{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.hm.unixporn;
in
{
  imports = [ ];

  # TODO: support dark/light variant? But I don't need too much skins
  options.kurisu.hm.unixporn.whitesur = { };

  config = lib.mkIf (cfg.enable && cfg.style == "whitesur") {
    gtk = {
      enable = true;
      theme = {
        name = "WhiteSur-Dark";
        package = pkgs.whitesur-gtk-theme;
      };
      iconTheme = {
        name = "WhiteSur-dark";
        package = pkgs.whitesur-icon-theme;
      };
      cursorTheme = {
        name = "WhiteSur-cursors";
        package = pkgs.whitesur-cursors;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "qtct";
      style = {
        name = "kvantum";
      };
      qt5ctSettings = {
        Appearance = {
          style = "kvantum";
          icon_theme = "WhiteSur-dark";
          custom_palette = true;
          color_scheme_path = toString ../../../dotfile/qt6ct/style-colors.conf;
          standard_dialogs = "default";
        };
        Font = {
          fixed = "SF Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular,0,0";
          general = "SF Pro,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        };
        Interface = {
          activate_item_on_single_click = 1;
          buttonbox_layout = 0;
          cursor_flash_time = 1000;
          dialog_buttons_have_icons = 1;
          double_click_interval = 400;
          gui_effects = "General, AnimateMenu";
          keyboard_scheme = 2;
          menus_have_icons = true;
          show_shortcuts_in_context_menus = true;
          stylesheets = "@Invalid()";
          toolbutton_style = 4;
          underline_shortcut = 1;
          wheel_scroll_lines = 3;
        };
        Troubleshooting = {
          force_raster_widgets = "1";
          ignored_applications = "@Invalid()";
        };
      };
      qt6ctSettings = {
        Appearance = {
          style = "kvantum";
          icon_theme = "WhiteSur-dark";
          custom_palette = true;
          color_scheme_path = toString ../../../dotfile/qt6ct/style-colors.conf;
          standard_dialogs = "default";
        };
        Font = {
          fixed = "SF Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular,0,0";
          general = "SF Pro,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
        };
        Interface = {
          activate_item_on_single_click = 1;
          buttonbox_layout = 0;
          cursor_flash_time = 1000;
          dialog_buttons_have_icons = 1;
          double_click_interval = 400;
          gui_effects = "General, AnimateMenu";
          keyboard_scheme = 2;
          menus_have_icons = true;
          show_shortcuts_in_context_menus = true;
          stylesheets = "@Invalid()";
          toolbutton_style = 4;
          underline_shortcut = 1;
          wheel_scroll_lines = 3;
        };
        Troubleshooting = {
          force_raster_widgets = "1";
          ignored_applications = "@Invalid()";
        };
      };
    };

    xdg.configFile = {
      "Kvantum/kvantum.kvconfig".source = (pkgs.formats.ini { }).generate "kvantum.kvconfig" {
        General.theme = "WhiteSurDark";
      };
      "Kvantum/WhiteSur".source = pkgs.runCommand "fixup-whitesur-theme" { } ''
        cp -rT ${pkgs.whitesur-kde}/share/Kvantum/WhiteSur "$out"
        chmod -R u+w "$out"
        sed -i "s/transparent_dolphin_view=true/transparent_dolphin_view=false/" "$out/WhiteSurDark.kvconfig"
      '';
    };
  };
}
