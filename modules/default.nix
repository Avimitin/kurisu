{ ... }:
{
  flake.homeModules = import ./hm;
  flake.nixosModules = import ./os;
}
