{
  home-manager,
  withSystem,
  self,
  ...
}@inputs:
{
  homelab = home-manager.lib.homeManagerConfiguration (
    withSystem "x86_64-linux" (
      { pkgs, ... }:
      {
        inherit pkgs;
        modules = [
          self.homeModules.default
          {
            _module.args = {
              flake-inputs = inputs;
            };
          }
          ./machines/homelab.nix
        ];
      }
    )
  );
}
