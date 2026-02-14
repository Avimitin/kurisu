{
  description = "Flakes to setup my configuration";

  inputs = {
    # Unstable nixpkgs for latest packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-2511.url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-25.11/nixexprs.tar.xz";

    # Configure flake as module
    flake-parts.url = "github:hercules-ci/flake-parts";

    # User home configuration
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # My neovim bundle
    nvim.url = "github:Avimitin/nvim";

    # Nix formatter
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix Devops for machine nix configuration deployment
    colmena.url = "github:zhaofengli/colmena";

    # System widgets for Niri
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko?tag=v1.13.0";
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
          ./nix/flake/colmenaToNixOS.nix
          inputs.treefmt-nix.flakeModule
          inputs.home-manager.flakeModules.home-manager
        ];

        flake = {
          homeModules.default = import ./nix/home;
          nixosModules = import ./nix/system;

          # colmenaHive controls how NixOS machine deploy
          colmenaHive = import ./nix/colmena.nix inputs;

          # homeConfigurations controls how other distro machine deploy
          homeConfigurations = import ./nix/discrete.nix inputs;
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

            packages.colmena = inputs'.colmena.packages.colmena;

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
