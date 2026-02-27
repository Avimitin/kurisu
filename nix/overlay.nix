final: prev: {
  rime-dict =
    let
      src = final.fetchFromGitHub {
        repo = "rime-extended-dict";
        owner = "Avimitin";
        rev = "e46a1a2c42f00cb08eb797cb426469656e1f661e";
        hash = "sha256-UfgGvuV7yo3/wOH4/4TCRGqX5nxT5wVsFb4rrdXqYKU=";
      };
    in
    final.callPackage src { };

  mkAppleFonts = final.callPackage ./pkgs/make-apple-fonts.nix { };

  qbitorrent-cli = final.callPackage ./pkgs/qbittorrent-cli.nix { };

  dms-plugins = final.fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "dms-plugins";
    rev = "0de003833c3677abd1c80bd3e200a59756b51590";
    hash = "sha256-t5aqLWTqCW6BGhqmJpQ5MtQVEiUo0lktiTwxEJ3w1mE=";
  };

  opencode = prev.opencode.overrideAttrs (oldAttrs: rec {
    version = "1.2.15";
    src = final.fetchFromGitHub {
      owner = "anomalyco";
      repo = "opencode";
      tag = "v${version}";
      hash = "sha256-26MV9TbyAF0KFqZtIHPYu6wqJwf0pNPdW/D3gDQEUlQ=";
    };

    node_modules = oldAttrs.node_modules.overrideAttrs {
      outputHash = "sha256-Diu/C8b5eKUn7MRTFBcN5qgJZTp0szg0ECkgEaQZ87Y=";
    };
  });
}
