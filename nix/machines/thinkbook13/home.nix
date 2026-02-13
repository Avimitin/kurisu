{
  self,
  inputs,
  pkgs,
  ...
}:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.sh1marin = {
    news.display = "silent";

    home = {
      username = "sh1marin";
      homeDirectory = "/home/sh1marin";
      stateVersion = "25.11";
    };

    imports = [
      self.homeModules.default
      inputs.dms.homeModules.dank-material-shell
    ];

    kurisu.coding-env = {
      enable = true;
      enableLsp = true;
      enableAI = true;
      configureBash = true;
      extraPackages = [
        inputs.nvim.packages.${pkgs.stdenv.hostPlatform.system}.neovim # my neovim
      ];
    };

    kurisu.desktop = {
      enable = true;
    };

    programs.dank-material-shell = {
      enable = true;
      systemd = {
        enable = true;
        restartIfChanged = true;
      };
      # niri = {
      #   enableKeybinds = true;
      #   enableSpawn = true;
      # };
    };

    home.packages = [ pkgs.ffmpeg ];

    programs.obs-studio.enable = true;
  };
}
