{ lib, config, ... }:

let
  cfg = config.flake.colmenaHive;
in
{
  options.flake.colmenaHive = lib.mkOption {
    type = lib.types.attrsOf lib.types.raw;
    default = { };
  };

  config = {
    # Exposed nixosConfigurations when colmenaHive is defined, thus
    # the nixos-rebuild and other nix DevOps tools are still able
    # to query this flake
    flake.nixosConfigurations = cfg.nodes;
  };
}
