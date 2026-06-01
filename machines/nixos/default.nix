{ nixpkgs, self, ... }@inputs:
{
  thinkbook13 = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ (import ../../nix/overlay.nix { inherit inputs; }) ];
    };
    specialArgs = {
      inherit self inputs;
      myLibBuilder = import ../../nix/myLib.nix;
    };
    modules = [
      { kurisu.machines.thinkbook13.isInstall = false; }
      ./thinkbook13
    ];
  };
}
