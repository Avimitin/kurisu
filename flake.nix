{
  description = "Flakes to setup my configuration";

  inputs = {
    # Unstable nixpkgs for latest packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    # Configure flake as module
    flake-parts.url = "github:hercules-ci/flake-parts";

    # User home configuration
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix formatter
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System widgets for Niri
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Automatic disk partition
    disko = {
      url = "github:nix-community/disko?tag=v1.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      treefmt-nix,
      ...
    }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      {
        systems = inputs.nixpkgs.lib.systems.flakeExposed;

        imports = [
          ./modules

          inputs.treefmt-nix.flakeModule
          inputs.home-manager.flakeModules.home-manager
        ];

        flake = {
          inherit inputs;

          # nixosConfigurations for NixOS machine deploy
          nixosConfigurations = import ./machines/nixos inputs;

          # homeConfigurations controls how other distro machine deploy
          homeConfigurations = import ./machines/standalone inputs;
        };

        perSystem =
          { system, inputs', ... }:
          let
            pkgs = import inputs.nixpkgs {
              inherit system;
            };
          in
          {
            # Override the default "pkgs" attribute in per-system config.
            # This work as same as `specialArgs`
            _module.args.pkgs = pkgs;
            legacyPackages = pkgs;

            devShells.default = pkgs.mkShellNoCC {
              buildInputs = [ ];
            };

            apps.home-manager = {
              type = "app";
              program = inputs'.home-manager.packages.home-manager;
            };
            treefmt = {
              projectRootFile = "flake.nix";
              settings.on-unmatched = "debug";
              programs = {
                nixfmt.enable = true;
              };
            };
          };
      }
    );
}
