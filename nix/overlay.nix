{ inputs }:

final: prev:
let
  # The stock nixpkgs build compiles remote_server in the GUI invocation and
  # produces a dynamically linked binary. Build it separately below so it can
  # be a portable musl executable and so the editor does not build it twice.
  unpatchedZedEditor = prev.zed-editor.override {
    buildRemoteServer = false;
  };

  unprocessedZedRemoteServer =
    if final.stdenv.hostPlatform.system == "x86_64-linux" then
      final.callPackage ./pkgs/zed-remote-server.nix {
        inherit unpatchedZedEditor;
      }
    else
      null;

  zedRemoteServer =
    if unprocessedZedRemoteServer != null then
      final.callPackage ./pkgs/zed-remote-server-package.nix {
        unprocessedRemoteServer = unprocessedZedRemoteServer;
      }
    else
      null;
in
{
  rime-dict =
    let
      src = final.fetchFromGitHub {
        repo = "rime-extended-dict";
        owner = "Avimitin";
        rev = "e46a1a2c42f00cb08eb797cb426469656e1f661e";
        hash = "sha256-UfgGvuV7yo3/wOH4/4TCRGqX5nxT5wVsFb4rrdXqYKU=";
      };
    in
    final.callPackage src { };

  mkAppleFonts = final.callPackage ./pkgs/make-apple-fonts.nix { };

  zed-editor = final.callPackage ./pkgs/zed-editor.nix {
    inherit unpatchedZedEditor;
    inherit zedRemoteServer;
  };

  zed-remote-server = zedRemoteServer;

  pathy-server = final.callPackage ./pkgs/pathy-server.nix { };

  zed-extensions-path-only = final.lib.recurseIntoAttrs (
    final.callPackage ./pkgs/zed-extensions-path-only.nix { }
  );

  qbitorrent-cli = final.callPackage ./pkgs/qbittorrent-cli.nix { };

  dms-plugins = final.fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "dms-plugins";
    rev = "9e2752586d79a6509b93c00c6fa4be0334ae4755";
    hash = "sha256-QgeeB6Ix8L5oaqTUCopPvGu6vr0ECsF+jO3mQIxPKIw=";
  };

  inherit (import inputs.nixpkgs-master { system = final.stdenv.hostPlatform.system; })
    opencode
    niri
    ;
}
