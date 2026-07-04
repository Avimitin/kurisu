{
  pkgs,
  self,
  config,
  ...
}:
{
  imports = [
    self.homeModules.tools

  ];

  config = {
    news.display = "silent";

    nixpkgs.config.allowUnfree = true;

    nix.package = pkgs.nix;
    # Simply run nix run k#hello to run temporary programs
    nix.registry.k.to = {
      type = "path";
      path = "${config.home.homeDirectory}/kurisu";
    };

    home = {
      username = "avimitin";
      homeDirectory = "/home/avimitin";
      stateVersion = "25.11";
    };

    kurisu = {
      hm.tools = {
        enable = true;
        enableLsp = true;
        enableAI = true;
        configureBash = true;
      };
    };

  };
}
