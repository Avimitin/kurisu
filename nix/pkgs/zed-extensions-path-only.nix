{ zed-extensions }:

{
  inherit (zed-extensions)
    catppuccin-icons
    fleet-themes
    fish
    nix
    scala
    ;

  typst = zed-extensions.typst.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./typst-zed-path-only.patch ];
  });
}
