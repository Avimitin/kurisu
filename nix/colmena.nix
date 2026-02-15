{
  self,
  colmena,
  nixpkgs,
  ...
}@inputs:
colmena.lib.makeHive {
  meta.nixpkgs.lib = nixpkgs.lib;

  # I would like to configure Nixpkgs per machine based
  meta.nodeNixpkgs = {
    thinkbook13 = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ (import ./flake/overlay.nix) ];
    };
  };

  meta.specialArgs = {
    inherit self inputs;
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
      { kurisu.thinkbook13.isInstall = false; }
      ./machines/thinkbook13
    ];
  };
}
