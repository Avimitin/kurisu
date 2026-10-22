{
  lib,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  gsettings-desktop-schemas,
  gtk3,
  pkg-config,
  webkitgtk_4_1,
  wrapGAppsHook3,
}:

let
  version = "unstable-2026-10-05";

  src = fetchFromGitHub {
    owner = "chiaki-ng";
    repo = "akira";
    rev = "5913e829a95becadf8aa98780582512620bbee03";
    hash = "sha256-TP/H7iK4Y9zlwhHx4U0OgQJRTu2k6yopOdkXWFSX5Js=";
  };

  # Wails embeds `frontend/dist` with `//go:embed` at compile time, so the
  # React/Vite frontend has to be built before Go runs.
  frontend = buildNpmPackage {
    pname = "akira-companion-frontend";
    inherit version src;

    sourceRoot = "source/apps/akira-companion/frontend";
    npmDepsHash = "sha256-SypC8F9UFN57IMW1xGCSNSgSGqLQWC/Olyjo5BrmQ6s=";
    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r dist/. $out/

      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "akira-companion";
  inherit version src;

  # The Go module for the companion lives next to its frontend, not at the
  # repository root.
  modRoot = "apps/akira-companion";
  subPackages = [ "." ];

  vendorHash = "sha256-5PlS6Y4RA4A5j95jloU2ZdlFThIhHLRfymJO8nnGtrY=";

  # Wails links against GTK/WebKitGTK and needs the `webkit2_41` tag to pick
  # webkit2gtk-4.1 instead of the EOL 4.0 series. `production` makes the
  # binary serve the embedded frontend rather than the dev server.
  tags = [
    "desktop"
    "production"
    "webkit2_41"
  ];

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    gsettings-desktop-schemas
    gtk3
    webkitgtk_4_1
  ];

  postPatch = ''
    rm -rf apps/akira-companion/frontend/dist
    cp -r ${frontend} apps/akira-companion/frontend/dist
    chmod -R u+w apps/akira-companion/frontend/dist
  '';

  meta = {
    description = "Desktop companion for Akira, a PS Remote Play client for the Nintendo Switch";
    homepage = "https://github.com/chiaki-ng/akira";
    license = lib.licenses.agpl3Only;
    mainProgram = "akira-companion";
    platforms = lib.platforms.linux;
  };
}
