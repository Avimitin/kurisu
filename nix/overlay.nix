{ inputs }:

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

  zed-editor = final.callPackage ./pkgs/zed-editor.nix {
    unpatchedZedEditor = prev.zed-editor;
  };

  zed-extensions-path-only = final.lib.recurseIntoAttrs (
    final.callPackage ./pkgs/zed-extensions-path-only.nix { }
  );

  qbitorrent-cli = final.callPackage ./pkgs/qbittorrent-cli.nix { };

  dms-plugins = final.fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "dms-plugins";
    rev = "9e2752586d79a6509b93c00c6fa4be0334ae4755";
    hash = "sha256-QgeeB6Ix8L5oaqTUCopPvGu6vr0ECsF+jO3mQIxPKIw=";
  };

  inherit (import inputs.nixpkgs-master { system = final.stdenv.hostPlatform.system; })
    opencode
    niri
    ;
}
