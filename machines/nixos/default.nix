{
  self,
  colmena,
  nixpkgs,
  ...
}@inputs:
colmena.lib.makeHive {
  meta = {
    nixpkgs.lib = nixpkgs.lib;

    # I would like to configure Nixpkgs per machine based
    nodeNixpkgs = {
      thinkbook13 = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ (import ../../nix/overlay.nix { inherit inputs; }) ];
      };
    };

    # Let all modules access flake, flake inputs and my library
    specialArgs = {
      inherit self inputs;
      myLibBuilder = import ../../nix/myLib.nix;
    };
  };

  thinkbook13 = {
    deployment = {
      # Allow local deployment with `colmena apply-local`
      allowLocalDeployment = true;

      # Disable SSH deployment. This node will be skipped in a
      # normal`colmena apply`.
      targetHost = null;
    };

    imports = [
      # Change to true when installing machine
      { kurisu.machines.thinkbook13.isInstall = false; }
      ./thinkbook13
    ];
  };
}
