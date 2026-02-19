{
  self,
  home-manager,
  nixpkgs,
  ...
}@inputs:
{
  homelab = home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ (import ../nix/overlay.nix) ];
    };

    modules = [
      self.homeModules.default
      ./machines/homelab.nix
    ];

    extraSpecialArgs = {
      inherit self inputs;
    };
  };
}
