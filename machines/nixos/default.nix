{ nixpkgs, self, ... }@inputs:
let
  mkHost =
    modules:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ (import ../../nix/overlay.nix { inherit inputs; }) ];
      };
      specialArgs = {
        inherit self inputs;
        myLibBuilder = import ../../nix/myLib.nix;
      };
      inherit modules;
    };
in
{
  thinkbook13 = mkHost [ ./thinkbook13 ];
  thinkbook13-bootstrap = mkHost [ ./thinkbook13/bare.nix ];
}
