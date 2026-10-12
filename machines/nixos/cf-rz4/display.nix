{ pkgs, ... }:
let
  # Names from the working Arch Intel DDX, including its DP-to-VGA bridge.
  # The modesetting DDX would rename these to DP-1/eDP-1.
  crtOutput = "DP1";
  panelOutput = "eDP1";
  modeName = "bvm-480i-525";
  # Based on ~/screen.sh, with the vertical total corrected from 526 to 525.
  # The user confirmed sharper text in a live comparison on the BVM.
  # 15.750 kHz horizontal, 60 fields/s, 30 complete frames/s.
  modeline = "12.60 640 680 744 800 480 486 492 525 interlace -hsync -vsync";

  setOutput = pkgs.writeShellApplication {
    name = "bvm-output";
    runtimeInputs = [
      pkgs.xrandr
      pkgs.gnugrep
    ];
    text = ''
      if xrandr --query | grep '^${crtOutput} connected' > /dev/null; then
        # The mode is registered by Xorg. Never select --auto on the CRT:
        # its bridge advertises a progressive 31 kHz 640x480 fallback.
        if xrandr --output ${crtOutput} --mode ${modeName} --primary \
            --pos 0x0 --rotate normal --transform none --scale 1x1 \
            --panning 0x0; then
          # Turn off the LCD only after the CRT mode has been accepted.
          xrandr --output ${panelOutput} --off
        else
          echo 'Could not set BVM 480i; enabling the laptop panel.' >&2
          xrandr --output ${crtOutput} --off \
            --output ${panelOutput} --auto --primary --pos 0x0
        fi
      else
        xrandr --output ${crtOutput} --off \
          --output ${panelOutput} --auto --primary --pos 0x0
      fi
    '';
  };
in
{
  services.xserver = {
    enable = true;
    # Match the driver that already successfully produces interlaced output.
    videoDrivers = [ "intel" ];
    # The packaged Intel DDX references these modules at load time. Preload
    # them to avoid undefined vbeFree/vgaHWProtect/ShadowFBInit symbols.
    moduleSection = ''
      Load "int10"
      Load "vgahw"
      Load "shadowfb"
    '';
    dpi = 96;
    desktopManager.xfce.enable = true;

    deviceSection = ''
      Option "Monitor-${crtOutput}" "Sony-BVM"
    '';
    # Keep the 15 kHz limits local to DP1, not the internal LCD.
    extraConfig = ''
      Section "Monitor"
        Identifier "Sony-BVM"
        ModelName "Sony BVM-9045D"
        HorizSync 15.6-15.9
        VertRefresh 59-61
        Modeline "${modeName}" ${modeline}
        Option "PreferredMode" "${modeName}"
        Option "Primary" "true"
        Option "Position" "0 0"
      EndSection
    '';

    displayManager = {
      lightdm = {
        enable = true;
        greeters.gtk.extraConfig = ''
          font-name=DejaVu Sans Bold 14
          xft-antialias=true
          xft-hintstyle=hintslight
          xft-rgba=none
        '';
      };
      # Set the output before the greeter, and again before the user session.
      setupCommands = "${setOutput}/bin/bvm-output";
      sessionCommands = "${setOutput}/bin/bvm-output";
    };
  };
  services.displayManager = {
    defaultSession = "xfce";
    autoLogin = {
      enable = true;
      user = "sh1marin";
    };
  };

  environment.systemPackages = [
    setOutput
    pkgs.xrandr
  ];

  # Grayscale antialiasing: LCD RGB subpixel rendering is unsuitable here.
  fonts = {
    packages = [ pkgs.dejavu_fonts ];
    fontconfig = {
      antialias = true;
      hinting.style = "slight";
      subpixel = {
        rgba = "none";
        lcdfilter = "none";
      };
      defaultFonts = {
        sansSerif = [ "DejaVu Sans" ];
        monospace = [ "DejaVu Sans Mono" ];
      };
    };
  };

  # System defaults for fresh XFCE accounts; personal settings can override
  # these. Do not restore an old displays.xml that selects progressive modes.
  environment.etc = {
    "xdg/xfce4/xfconf/xfce-perchannel-xml/displays.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="displays" version="1.0">
        <property name="AutoEnableProfiles" type="int" value="0"/>
        <property name="Notify" type="int" value="0"/>
      </channel>
    '';
    "xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xsettings" version="1.0">
        <property name="Gtk" type="empty">
          <property name="FontName" type="string" value="DejaVu Sans Bold 14"/>
          <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono Bold 14"/>
        </property>
        <property name="Gdk" type="empty">
          <property name="WindowScalingFactor" type="int" value="1"/>
        </property>
        <property name="Xft" type="empty">
          <property name="DPI" type="int" value="96"/>
          <property name="Antialias" type="int" value="1"/>
          <property name="Hinting" type="int" value="1"/>
          <property name="HintStyle" type="string" value="hintslight"/>
          <property name="RGBA" type="string" value="none"/>
        </property>
      </channel>
    '';
    "xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfwm4" version="1.0">
        <property name="general" type="empty">
          <property name="use_compositing" type="bool" value="false"/>
          <property name="title_font" type="string" value="DejaVu Sans Bold 14"/>
        </property>
      </channel>
    '';
    "xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfce4-terminal" version="1.0">
        <property name="font-use-system" type="bool" value="false"/>
        <property name="font-name" type="string" value="DejaVu Sans Mono Bold 14"/>
        <property name="misc-default-geometry" type="string" value="50x16"/>
      </channel>
    '';
  };
}
