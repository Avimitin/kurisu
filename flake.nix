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
          inputs.treefmt-nix.flakeModule
        ];

        # colmenaHive is the central collection of all the NixOS configuration
        flake.colmenaHive = import ./nix/machines.nix inputs;

        flake = {
          homeConfigurations = {
            "homelab" = inputs.home-manager.lib.homeManagerConfiguration (
              withSystem "x86_64-linux" (
                { pkgs, ... }:
                {
                  inherit pkgs;
                  modules = [
                    ./nix/home/homelab.nix
                  ];
                }
              )
            );
          };
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

            # Although the pkgs attribute is already override, but I am afraid
            # that the magical evaluation of "pkgs" is confusing, and will lead
            # to debug hell. So here we use the "pkgs" in "let-in binding" to
            # explicitly told every user we are using an overlayed version of
            # nixpkgs.
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
