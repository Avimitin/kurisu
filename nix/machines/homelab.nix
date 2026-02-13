{ flake-inputs, pkgs, ... }:
{
  news.display = "silent";

  nixpkgs.config.allowUnfree = true;

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
      extraPackages = [
        flake-inputs.nvim.packages.${pkgs.stdenv.hostPlatform.system}.neovim # my neovim
      ];
    };

    desktop = {
      enable = true;
    };
  };
}
