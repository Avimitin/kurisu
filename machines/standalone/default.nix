{
  self,
  home-manager,
  nixpkgs,
  ...
}@inputs:
{
  homelab = home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [
        (import ../../nix/overlay.nix { inherit inputs; })
      ];
    };

    modules = [
      ./homelab.nix
    ];

    extraSpecialArgs = {
      inherit self inputs;
    };
  };

  biyun = home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };

    modules = [
      ./biyun.nix
    ];

    extraSpecialArgs = {
      inherit self inputs;
    };
  };
}
