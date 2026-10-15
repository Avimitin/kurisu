{
  cacert,
  fetchFromGitHub,
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "mekabridge";
  # 0.19+ needs meka >= 0.71, whose API requires a broader mekadsh migration.
  version = "0.18.2";

  src = fetchFromGitHub {
    owner = "k4yt3x";
    repo = "mekabridge";
    rev = "bf46cf1bde8a8c6bc897ea87e3fdea0ca04843cd";
    hash = "sha256-GNPFiXNhXhei4n6phSotQL4Gd6r+C/tJFn+GVBNlObQ=";
  };

  cargoHash = "sha256-BQr4UpgRihrclM+tUJiJqPVz8GDyYEDEhGqpEqkxIMc=";

  # The Discord unit tests construct HTTPS clients even without network access.
  nativeCheckInputs = [ cacert ];

  meta = {
    description = "Bridge between meka and Telegram or Discord";
    homepage = "https://github.com/k4yt3x/mekabridge";
    license = lib.licenses.mit;
    mainProgram = "mekabridge";
    platforms = lib.platforms.unix;
  };
}
