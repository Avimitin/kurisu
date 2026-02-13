{
  home-manager,
  withSystem,
  self,
  ...
}:
{
  homelab = home-manager.lib.homeManagerConfiguration (
    withSystem "x86_64-linux" (
      { pkgs, ... }:
      {
        inherit pkgs;
        modules = [
          self.homeModules.default
          ./machines/homelab.nix
        ];
      }
    )
  );
}
