{
  gzip,
  lib,
  patchelf,
  runCommand,
  unprocessedRemoteServer,
}:

runCommand "zed-remote-server-${unprocessedRemoteServer.version}"
  {
    inherit (unprocessedRemoteServer) version;

    nativeBuildInputs = [
      gzip
      patchelf
    ];

    passthru.unprocessed = unprocessedRemoteServer;

    meta = {
      description = "Portable remote development server matching Zed ${unprocessedRemoteServer.version}";
      license = lib.licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
    };
  }
  ''
    gzip -dc ${unprocessedRemoteServer}/share/zed/remote_server.gz > remote_server
    chmod +x remote_server

    # Static PIE executables still have a dynamic section for relocations.
    # Nix's static stdenv leaves an unnecessary RUNPATH there even though the
    # binary has no DT_NEEDED entries. Remove it before shipping the artifact.
    patchelf --remove-rpath remote_server

    mkdir -p "$out/share/zed"
    gzip -9 -n -c remote_server > "$out/share/zed/remote_server.gz"
  ''
