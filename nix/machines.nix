{
  self,
  colmena,
  nixpkgs,
  nixpkgs-2511,
  home-manager,
  ...
}@inputs:
colmena.lib.makeHive {
  meta.nixpkgs.lib = nixpkgs.lib;

  # I would like to configure Nixpkgs per machine based
  meta.nodeNixpkgs = {
    thinkbook13 = import nixpkgs-2511 {
      system = "x86_64-linux";
      overlays = [ ];
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
      home-manager.nixosModules.home-manager
      # Gives modules ability to access flake input
      {
        _module.args = { inherit self; };
        home-manager.extraSpecialArgs = {
          flake-inputs = inputs;
        };
      }
      ./nixos_machines/thinkbook13
    ];
  };
}
