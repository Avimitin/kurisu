{
  fetchFromGitHub,
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "meka";
  version = "0.68.0";

  src = fetchFromGitHub {
    owner = "k4yt3x";
    repo = "meka";
    rev = "41db1959534e21c7204a6f8dc9aea82e64fff0f5";
    hash = "sha256-B3mimis2oX4Ny5Ul0gaerINLk+dcX5t/s2ovZCk0IG4=";
  };

  cargoHash = "sha256-sohrA1K1hQrALJnhAiPE+Agq87CJd8dDLTvMW3gHd1Y=";

  # The test suite imports `crate::provider::mock`, which is only compiled
  # under `debug_assertions` or the `mock-provider` feature. `cargoCheckHook`
  # runs `cargo test` in the release profile, so `mock` is gated out and the
  # harness fails to compile. The integration tests (serve, ACP, PTY REPL,
  # multiprocess) are also heavyweight and unsuited to the sandbox, so skip
  # them.
  doCheck = false;

  meta = {
    description = "A general-purpose AI agent harness";
    homepage = "https://github.com/k4yt3x/meka";
    license = lib.licenses.agpl3Plus;
    mainProgram = "meka";
    platforms = lib.platforms.unix;
  };
}
