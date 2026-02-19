final: prev: {
  rime-dict = final.callPackage ./pkgs/rime-dict/package.nix { };

  mkAppleFonts = final.callPackage ./pkgs/make-apple-fonts.nix { };

  qbitorrent-cli = final.callPackage ./pkgs/qbittorrent-cli.nix { };

  dms-plugins = final.fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "dms-plugins";
    rev = "0de003833c3677abd1c80bd3e200a59756b51590";
    hash = "sha256-t5aqLWTqCW6BGhqmJpQ5MtQVEiUo0lktiTwxEJ3w1mE=";
  };
}
