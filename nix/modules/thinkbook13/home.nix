{ self, ... }:
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
    ];

    kurisu.coding-env = {
      enable = true;
      enableLsp = true;
      enableAI = true;
      configureBash = true;
    };

    kurisu.desktop = {
      enable = true;
    };
  };
}
