{
  lib,
  stdenv,
  unpatchedZedEditor,
  zedRemoteServer ? null,
}:

assert lib.assertMsg (unpatchedZedEditor.version == "1.16.1") ''
  The Zed patches were audited against zed-editor 1.16.1, but
  nixpkgs now provides ${unpatchedZedEditor.version}. Rebase and re-audit
  nix/pkgs/zed-*.patch before updating this assertion.
'';
assert lib.assertMsg
  (zedRemoteServer == null || zedRemoteServer.version == unpatchedZedEditor.version)
  ''
    The bundled remote server (${zedRemoteServer.version}) must be built from the
    same Zed source as the editor (${unpatchedZedEditor.version}).
  '';
unpatchedZedEditor.overrideAttrs (oldAttrs: {
  patches =
    (oldAttrs.patches or [ ])
    ++ [
      ./zed-no-automatic-downloads.patch
      ./zed-extension-checksums.patch
      ./zed-linux-system-notifications.patch
      ./zed-pixel-scroll.patch
    ]
    ++ lib.optional (zedRemoteServer != null) ./zed-local-remote-server.patch;

  env =
    (oldAttrs.env or { })
    // lib.optionalAttrs (zedRemoteServer != null) {
      ZED_BUNDLED_REMOTE_SERVER = "${zedRemoteServer}/share/zed/remote_server.gz";
      ZED_BUNDLED_REMOTE_SERVER_OS = if stdenv.hostPlatform.isLinux then "linux" else "macos";
      ZED_BUNDLED_REMOTE_SERVER_ARCH = if stdenv.hostPlatform.isx86_64 then "x86_64" else "aarch64";
    };

  passthru =
    (oldAttrs.passthru or { })
    // lib.optionalAttrs (zedRemoteServer != null) {
      remote_server = zedRemoteServer;
    };
})
