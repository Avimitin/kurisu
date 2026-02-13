{ ... }:
{
  news.display = "silent";

  home = {
    username = "sh1marin";
    homeDirectory = "/home/sh1marin";
    stateVersion = "25.11";
  };

  kurisu = {
    coding-env = {
      enable = true;
      enableLsp = true;
      enableAI = true;
      configureBash = true;
    };

    desktop = {
      enable = true;
    };
  };
}
