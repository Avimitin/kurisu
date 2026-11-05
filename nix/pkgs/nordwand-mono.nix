{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  installFonts,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "nordwand-mono";
  version = "1.5.1";

  src = fetchurl {
    url = "https://github.com/tywr/Nordwand-Mono/releases/download/${finalAttrs.version}/NordwandMono-TTF.zip";
    hash = "sha256-iMMX2lZkc+rpvjptlHVe6hcIbRAT0ZwUn8ESbPNkv6Q=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    unzip
    installFonts
  ];

  dontConfigure = true;
  dontBuild = true;

  meta = {
    description = "Compact neo-grotesk monospaced typeface for programming";
    homepage = "https://github.com/tywr/Nordwand-Mono";
    changelog = "https://github.com/tywr/Nordwand-Mono/releases/tag/${finalAttrs.version}";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
