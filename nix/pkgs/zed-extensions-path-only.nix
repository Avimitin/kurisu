{
  buildZedExtension,
  buildZedRustExtension,
  fetchFromGitHub,
  zed-extensions,
}:

let
  # The forked builders run postInstall after nix-zed-extensions has assembled
  # the final output. Hash relative file names and contents into Zed's normal-
  # installation receipt; unmarked symlinks remain development extensions.
  withExtensionChecksum =
    extension:
    extension.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        for extension_dir in "$out"/share/zed/extensions/*; do
          if [ -d "$extension_dir" ]; then
            (
              set -o pipefail
              cd "$extension_dir"
              find . \( -type f -o -type l \) ! -name .zed-extension-checksum -print0 \
                | LC_ALL=C sort -z \
                | xargs -0 sha256sum \
                | sha256sum \
                | cut -d ' ' -f 1 > .zed-extension-checksum
            )
          fi
        done
      '';
    });

  extensions = {
    inherit (zed-extensions)
      catppuccin-icons
      fish
      nix
      scala
      make
      ;

    # The pathy fork turns the Python-only completion server into a generic
    # one. Built from the fork so the manifest ships the full language list.
    # Keep the rev in sync with pkgs/pathy-server.nix.
    pathy = buildZedRustExtension {
      name = "pathy";
      version = "0.2.0";

      src = fetchFromGitHub {
        owner = "Avimitin";
        repo = "pathy";
        rev = "584d6f753262f0b1b6a68d10ae0165347e5dd911";
        hash = "sha256-KOKpxgNP0J22ju/XTjCpOSnz9+Qgl/8qWX6UMPmz+EU=";
      };

      cargoHash = "sha256-A3QKWGCGog7U1LcO5SAN7Av0QJzIXtiOS6x32Fywp0M=";
    };

    fleet-themes = buildZedExtension {
      name = "fleet-themes";
      version = "1.2.1";

      src = fetchFromGitHub {
        owner = "Avimitin";
        repo = "zed-fleet-themes";
        rev = "2705eaf8cdf1e46d7adb8f513825cc4b3ff3a3f5";
        hash = "sha256-C8V3xRatSNR9pygvyBi6Gip8GT3ETicwXrqvK+MNNHY=";
      };
    };

    typst = zed-extensions.typst.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [ ./typst-zed-path-only.patch ];
    });
  };
in
builtins.mapAttrs (_: withExtensionChecksum) extensions
