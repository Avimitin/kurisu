{
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "pathy-server";
  version = "0.2.0";

  # Keep in sync with the pathy extension revision used in
  # zed-extensions-path-only.nix, so the sidecar server and the WASM
  # wrapper always come from the same commit.
  src = fetchFromGitHub {
    owner = "Avimitin";
    repo = "pathy";
    rev = "f7d7c8f6887fcc50b6bb933be55426439a766455";
    hash = "sha256-O+Me1nVOj5n71HKXx/yNhGH24NBV6bvOqHNoSHfrrxA=";
  };

  # The repo root is the WASM extension wrapper; the LSP sidecar lives in
  # its own crate. The repo ships a Cargo.lock for the server crate.
  sourceRoot = "source/server";

  cargoHash = "sha256-6IB2kR2zIpJ5BD8eBP0X1o3eYNCsPlVJvQJGjL5cqts=";
}
