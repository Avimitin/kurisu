{
  lib,
  rustPlatform,
  makeBinaryWrapper,
  fontconfig,
  libGL,
  libxkbcommon,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
}:
let
  libraries = [
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in
rustPlatform.buildRustPackage {
  pname = "egui-askpass";
  version = "0.1.0";
  src = lib.cleanSource ./.;
  cargoHash = "sha256-JzJkuFI8MuaG8NOxbq+3oIULqWKuKWGNgesMhEbRHJ4=";

  nativeBuildInputs = [
    makeBinaryWrapper
  ];
  buildInputs = libraries;
  doCheck = false;

  postFixup = ''
    wrapProgram $out/bin/egui-askpass \
      --prefix PATH : ${lib.makeBinPath [ fontconfig ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath libraries}
  '';

  meta = {
    description = "Compact egui askpass helper for SSH security keys";
    mainProgram = "egui-askpass";
    platforms = lib.platforms.linux;
  };
}
