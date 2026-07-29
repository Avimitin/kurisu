{ lib, ... }:

{
  options.kurisu.hm.zed.enable =
    lib.mkEnableOption "Zed with this repository's declarative configuration";
}
