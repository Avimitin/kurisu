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
    rev = "9aea90e2c0b72dc53fd243cf7594a8c27f3e50b4";
    hash = "sha256-dPu7SOB4kES/XYz2znSnIa3Nbl8IReaxEG5H4O2l0xo=";
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
