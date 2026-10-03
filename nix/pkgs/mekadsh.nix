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
    rev = "74fbb75b3b2324d94207b7a043c9c4673789a7f7";
    hash = "sha256-XKV+whR0i9QV4yti1uLBwrbJ5eBnGc+lBhO1CrVmD4Q=";
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
