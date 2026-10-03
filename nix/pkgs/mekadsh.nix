{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nodejs_24,
}:

buildNpmPackage {
  pname = "mekadsh";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Avimitin";
    repo = "MekaDsh";
    rev = "e890695533edb040d04c2982b25a03e4c94981b6";
    hash = "sha256-RmVjr3ZIwbpwE5RZT9/9dXj+la2/RfhW4qjWJaDW7vg=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-oLDAaq8cOTMVWIJ3Eqc3+3EL1gZdk6n4PdsbxhPK+hw=";
  npmBuildScript = "build";

  # Vite emits a static site. The meka daemon remains the API backend.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r dist/. "$out"/
    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Harness style web interface for meka";
    homepage = "https://github.com/Avimitin/MekaDsh";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.unix;
  };
}
