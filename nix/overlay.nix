final: prev: {
  rime-dict = final.callPackage ./pkgs/rime-dict/package.nix { };

  mkAppleFonts = final.callPackage ./pkgs/mk-apple-fonts.nix { };

  qbitorrent-cli = final.callPackage ./pkgs/qbittorrent-cli.nix { };
}
