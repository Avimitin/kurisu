{ pkgs }:
let
  libraries = with pkgs; [
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    cargo
    rustc
    rustfmt
    fontconfig
  ];
  buildInputs = libraries;

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libraries;

  # Keep build artifacts out of the source copied by `nix develop path:.`.
  shellHook = ''
    export CARGO_TARGET_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/kurisu-egui-askpass/target"
  '';
}
