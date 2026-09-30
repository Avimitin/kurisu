{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
}:

buildNpmPackage {
  pname = "mekaweb";
  version = "0.13.1";

  src = fetchFromGitHub {
    owner = "k4yt3x";
    repo = "mekaweb";
    rev = "58213e799bdc318220c08cc707a129abc46e0bb7";
    hash = "sha256-dAUFM1T5cT4KwX791YQbuajC5PmwdYJ9gYZIGd1aiAo=";
  };

  npmDepsHash = "sha256-M5g5HfIIUrNGOL5Iiwi69SadK4w+XugU1U7McNWjELU=";

  # The default `npm run build` already runs `tsc --noEmit` before `vite
  # build`, so the checked-in OpenAPI schema does not need regenerating.
  npmBuildScript = "build";

  # mekaweb is a static SPA: the package is the Vite `dist/` output, ready to
  # serve from any static host (no backend or node_modules at runtime).
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r dist/. "$out"/
    runHook postInstall
  '';

  meta = {
    description = "Web interface for meka";
    homepage = "https://github.com/k4yt3x/mekaweb";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.unix;
  };
}
