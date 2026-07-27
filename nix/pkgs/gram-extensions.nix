{ zed-extensions }:

{
  inherit (zed-extensions) fish scala;

  typst = zed-extensions.typst.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./typst-zed-path-only.patch ];
  });
}
