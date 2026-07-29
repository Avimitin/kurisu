{
  lib,
  unpatchedZedEditor,
}:

assert lib.assertMsg (unpatchedZedEditor.version == "1.12.0") ''
  The Zed download-policy patch was audited against zed-editor 1.12.0, but
  nixpkgs now provides ${unpatchedZedEditor.version}. Rebase and re-audit
  nix/pkgs/zed-no-automatic-downloads.patch before updating this assertion.
'';
unpatchedZedEditor.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [ ./zed-no-automatic-downloads.patch ];
})
