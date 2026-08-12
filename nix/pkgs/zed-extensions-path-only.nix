{ zed-extensions }:

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
      fleet-themes
      fish
      nix
      scala
      make
      ;

    typst = zed-extensions.typst.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [ ./typst-zed-path-only.patch ];
    });
  };
in
builtins.mapAttrs (_: withExtensionChecksum) extensions
