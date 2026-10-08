{
  lib,
  rustPlatform,
  stdenv,
  stdenvAdapters,
  unpatchedZedEditor,
  zedRemoteServer ? null,
}:

let
  buildZedEditor =
    if stdenv.hostPlatform.isLinux then
      unpatchedZedEditor.override {
        rustPlatform = rustPlatform // {
          buildRustPackage = rustPlatform.buildRustPackage.override {
            stdenv = stdenvAdapters.useMoldLinker stdenv;
          };
        };
      }
    else
      unpatchedZedEditor;
in
# See zed-patches.md for the source and scope of the latest audit.
assert lib.assertMsg (unpatchedZedEditor.version == "1.22.0") ''
  The Zed patches were audited against zed-editor 1.22.0, but
  nixpkgs now provides ${unpatchedZedEditor.version}. Rebase and re-audit
  nix/pkgs/zed-*.patch before updating this assertion.
'';
assert lib.assertMsg
  (zedRemoteServer == null || zedRemoteServer.version == unpatchedZedEditor.version)
  ''
    The bundled remote server (${zedRemoteServer.version}) must be built from the
    same Zed source as the editor (${unpatchedZedEditor.version}).
  '';
buildZedEditor.overrideAttrs (oldAttrs: {
  patches =
    (oldAttrs.patches or [ ])
    ++ [
      ./zed-no-automatic-downloads.patch
      ./zed-extension-checksums.patch
      ./zed-linux-system-notifications.patch
      ./zed-pixel-scroll.patch
      # Zed PR #59188 at 4a8dd70244839745e665b5e4055cb53ba07024c0,
      # plus a rustfmt-only indentation fix.
      ./zed-flash-jump.patch
    ]
    ++ lib.optional (zedRemoteServer != null) ./zed-local-remote-server.patch;

  env =
    (oldAttrs.env or { })
    // lib.optionalAttrs stdenv.hostPlatform.isLinux {
      # Allow large release crates to generate code in parallel on builders.
      # Keep upstream's ThinLTO setting for release optimization.
      CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
    }
    // lib.optionalAttrs (zedRemoteServer != null) {
      ZED_BUNDLED_REMOTE_SERVER = "${zedRemoteServer}/share/zed/remote_server.gz";
      ZED_BUNDLED_REMOTE_SERVER_OS = if stdenv.hostPlatform.isLinux then "linux" else "macos";
      ZED_BUNDLED_REMOTE_SERVER_ARCH = if stdenv.hostPlatform.isx86_64 then "x86_64" else "aarch64";
    };

  preCheck = (oldAttrs.preCheck or "") + ''
    # The source archive has no Git metadata. Zed's test asset lookup needs a
    # checkout marker to find the bundled development assets at runtime.
    mkdir -p .git
  '';

  passthru =
    (oldAttrs.passthru or { })
    // lib.optionalAttrs (zedRemoteServer != null) {
      remote_server = zedRemoteServer;
    };
})
