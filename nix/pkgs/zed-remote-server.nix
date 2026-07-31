{
  cmake,
  gzip,
  lib,
  llvm,
  pkg-config,
  pkgsStatic,
  protobuf,
  unpatchedZedEditor,
}:

assert lib.assertMsg
  (pkgsStatic.stdenv.hostPlatform.isLinux && pkgsStatic.stdenv.hostPlatform.isx86_64)
  ''
    The portable Zed remote server is currently implemented only for x86_64-linux.
  '';
pkgsStatic.rustPlatform.buildRustPackage {
  pname = "zed-remote-server";
  inherit (unpatchedZedEditor) version src cargoDeps;

  patches = (unpatchedZedEditor.patches or [ ]) ++ [ ./zed-no-automatic-downloads.patch ];

  # Use the already-vendored dependency tree from the matching nixpkgs Zed
  # package, but compile this crate separately so GUI feature unification
  # cannot pull dynamic X11 dependencies into the remote server.
  cargoBuildFlags = [ "--package=remote_server" ];

  nativeBuildInputs = [
    cmake
    pkg-config
    protobuf
  ];

  dontUseCmakeConfigure = true;
  doCheck = false;

  postPatch = ''
    # Let buildRustPackage supply the musl target and linker configuration.
    rm .cargo/config.toml
  '';

  installPhase = ''
    runHook preInstall

    remote_server=target/${pkgsStatic.stdenv.hostPlatform.rust.cargoShortTarget}/release/remote_server
    ${lib.getExe' llvm "llvm-objcopy"} --strip-debug "$remote_server"

    mkdir -p "$out/share/zed"
    ${lib.getExe gzip} -9 -c "$remote_server" > "$out/share/zed/remote_server.gz"

    runHook postInstall
  '';

  meta = {
    description = "Statically linked remote development server matching Zed ${unpatchedZedEditor.version}";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
