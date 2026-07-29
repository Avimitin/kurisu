{ inputs, ... }:
{
  flake.homeModules = import ./hm { inherit inputs; };
  flake.nixosModules = import ./os;
}
