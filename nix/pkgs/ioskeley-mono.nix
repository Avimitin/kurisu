# Vendored from nixpkgs/pkgs/data/fonts/ioskeley-mono/default.nix.
# v2.1.0 fixes terminal ligatures and drops the Condensed width.
{
  lib,
  stdenvNoCC,
  fetchzip,
  installFonts,
}:

let
  version = "v2.1.0";

  mkFont =
    {
      width,
      variant ? "",
      hash,
      isNF ? false,
      hinted ? true,
    }:
    let
      fileName = "IoskeleyMono${if variant != "" then "-${variant}" else ""}${
        if isNF then "-NerdFont" else ""
      }.zip";
      hintDir = if hinted then "Hinted" else "Unhinted";

      pname =
        let
          wPart = "-${lib.toLower width}";
          vPart = if variant != "" then "-${variant}" else "";
          nfPart = if isNF then "-NF" else "";
          hPart = if !hinted && !isNF then "-unhinted" else "";
        in
        "ioskeley-mono${wPart}${vPart}${nfPart}${hPart}";
    in
    stdenvNoCC.mkDerivation {
      inherit pname version;

      src = fetchzip {
        url = "https://github.com/ahatem/IoskeleyMono/releases/download/${version}/${fileName}";
        stripRoot = false;
        inherit hash;
      };

      sourceRoot = if isNF then "source/${width}" else "source/${width}/${hintDir}";

      nativeBuildInputs = [ installFonts ];

      meta = {
        homepage = "https://github.com/ahatem/IoskeleyMono";
        description = "Iosevka configuration mimicking Berkeley Mono, ${width} width${
          if variant != "" then ", ${variant} variant" else ""
        }${if isNF then ", Nerd Font patched" else ""}${if !hinted then ", unhinted" else ""}";
        license = lib.licenses.ofl;
        platforms = lib.platforms.all;
        maintainers = with lib.maintainers; [ nuexq ];
      };
    };

  allWidths = [
    "Normal"
    "SemiCondensed"
  ];

  mkWidths =
    {
      suffix ? "",
      withHinting ? false,
      ...
    }@args:
    let
      mkWidthSet =
        hinted:
        map (w: {
          name = "${lib.strings.toLower (builtins.substring 0 1 w)}${builtins.substring 1 (-1) w}${
            if suffix != "" then "-${suffix}" else ""
          }${if !hinted then "-unhinted" else ""}";

          value = mkFont (
            {
              width = w;
              inherit hinted;
            }
            // (removeAttrs args [
              "suffix"
              "withHinting"
            ])
          );
        }) allWidths;
    in
    lib.listToAttrs (
      if withHinting then
        lib.concatMap (h: mkWidthSet h) [
          true
          false
        ]
      else
        mkWidthSet true
    );
in

# Standard
mkWidths {
  hash = "sha256-1WGAPwbfSG3fpssUTnHCTVI8eKNHSHWHdfdq4JUQ9ls=";
  withHinting = true;
}

# Term
// mkWidths {
  suffix = "term";
  variant = "Term";
  hash = "sha256-Ei6cRAMC9C62X8coHsTMvfPZfloiUp+A4HeT89df3pk=";
  withHinting = true;
}

// mkWidths {
  suffix = "term-NF";
  variant = "Term";
  isNF = true;
  hash = "sha256-joAhNADErBErDqTrNelJ0ulGZCN/OUZ1SMYyU++7l6U=";
}

# NL
// mkWidths {
  suffix = "NL";
  variant = "NL";
  hash = "sha256-3zqO7W23Zcdz7L8cO0A8oAH0PQqYUNwKiKnAmN/Ja8s=";
  withHinting = true;
}

// mkWidths {
  suffix = "NL-NF";
  variant = "NL";
  isNF = true;
  hash = "sha256-3eTVqMlLx/AF3aoTbQ68Qzhr5nQzWIKt4HWZZsH2yE0=";
}

# Nerd Font Standard
// mkWidths {
  suffix = "NF";
  isNF = true;
  hash = "sha256-b0mqhLeDT+uYPYiOKB+cxc5M1TtFkICKAmlcmW3IjDg=";
}
