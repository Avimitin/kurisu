{ ... }:
{
  imports = [
    ./colmenaToNixOS.nix
  ];

  flake.homeModules = import ./hm;
  flake.nixosModules = import ./os;
}
