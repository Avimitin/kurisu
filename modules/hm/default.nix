{ inputs }:

{
  tools = ./tools.nix;
  fcitx5 = ./fcitx5.nix;
  fontconfig = ./fontconfig.nix;
  terminal = ./terminal;
  unixporn = ./unixporn;
  gram = ./gram/myconfig.nix;
  zed = {
    imports = [
      ./zed/myconfig.nix
      inputs.nix-zed-extensions.homeManagerModules.default
    ];
  };
}
