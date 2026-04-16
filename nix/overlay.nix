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

  pure-prompt = prev.pure-prompt.overrideAttrs {
    version = "1.27.1";
    src = final.fetchFromGitHub {
      owner = "sindresorhus";
      repo = "pure";
      rev = "dbefd0dcafaa3ac7d7222ca50890d9d0c97f7ca2";
      hash = "sha256-Fhk4nlVPS09oh0coLsBnjrKncQGE6cUEynzDO2Skiq8=";
    };
  };

  niri = prev.niri.overrideAttrs (oldAttrs: rec {
    version = "unstable-2026-04-16";
    src = final.fetchFromGitHub {
      owner = "niri-wm";
      repo = "niri";
      rev = "71d7fa9a61ef56d2afa1fd5523089b96c1c5fc0f";
      hash = "sha256-D5ME/gcvzCqr2pqd8iw3Nx7v31CBdQLt5iFfF0PZKDw=";
    };

    env = oldAttrs.env // {
      NIRI_BUILD_VERSION_STRING = version;
    };

    postPatch = ''
      patchShebangs resources/niri-session
      substituteInPlace resources/niri.service \
        --replace-fail 'ExecStart=niri --session' "ExecStart=$out/bin/niri --session"
    '';

    cargoDeps = final.rustPlatform.fetchCargoVendor {
      name = oldAttrs.pname + "-cargo-vendor";
      inherit src;
      hash = "sha256-XbKhPJ/VxcLf4J2I6dekKnUvCnmoXndvQsLx2B04ihE=";
    };
  });
}
