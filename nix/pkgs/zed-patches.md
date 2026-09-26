# Zed patch audit

Audited on 2026-09-26 against Zed **1.21.0**, as packaged by nixpkgs
`d54020a6ac3211e9f4201631bdf67678818c0cdf`:

- Upstream source: `zed-industries/zed`, tag `v1.21.0`.
- Nix source hash: `sha256-RQttvkWuyWnPHsZ3FWzffklbUFjgALMYt7Kh9+N7tLE=`.
- Previous audit: 1.19.2. Compared both pinned source trees and reviewed the
  affected callers and implementations. All six patches remain necessary;
  their added and removed source lines are unchanged by this rebase.

Apply patches in the order in `zed-editor.nix`. The remote server applies only
`zed-no-automatic-downloads.patch`; the editor additionally applies
`zed-local-remote-server.patch` when a bundled server is available.

| Patch | Reviewed behavior in 1.21.0 |
| --- | --- |
| `zed-no-automatic-downloads.patch` | The sole production `get_language_server_binary` caller still controls built-in LSP downloads. All four Node runtime initializers disable managed Node downloads while retaining configured paths and PATH lookup. Extension startup still loads the index without launching automatic installs or updates. Extension-provided LSP commands use a separate API; their PATH-only behavior is supplied by `zed-extensions-path-only.nix`. |
| `zed-extension-checksums.patch` | Both extension extraction paths write a SHA-256 receipt. Index rebuilds and cached entries classify receipt-bearing symlinks as installed extensions; unmarked symlinks remain development extensions. Receipts identify installation provenance; loading checks their format, not the current directory contents. |
| `zed-linux-system-notifications.patch` | Both agent notification paths retain visibility and notification-setting guards. Linux uses GPUI system notifications and application identity; other platforms retain popup windows. The GPUI Linux notification interface is unchanged. |
| `zed-pixel-scroll.patch` | The setting is connected through defaults, deserialization, VS Code import, runtime settings, and both scroll callers. Precise scrolling remains limited to ordinary scrollback, with overscan, drawing, and mouse coordinates aligned; alternate-screen and mouse-reporting paths keep their existing behavior. |
| `zed-flash-jump.patch` | Action registration, waiting-mode input, inclusive motions, viewport clipping, and overlay cleanup remain compatible. All `Motion::Jump` constructors supply the new field, and operator-stack clearing goes through UI cleanup. Search bounds and the existing Flash regression tests are retained. |
| `zed-local-remote-server.patch` | Returning no download URL still makes SSH fall through to local upload. The local provider returns the Nix-built archive after checking the target OS/architecture and file existence. The editor/server version assertion remains in place. |

Validation used the pinned nixpkgs dependencies and Rust 1.98.1 on x86_64-linux:

- All six patches apply in package order with `patch --fuzz=0`, without offsets
  or rejected hunks. The resulting 30 files match the source used for compilation.
- `rustfmt --check` passes for all touched Rust files; `nixfmt --check` passes for
  `zed-editor.nix`; `git diff --check` passes.
- The actual x86_64-linux editor and bundled musl server derivations evaluate at
  1.21.0. Editor derivations without bundling also evaluate on x86_64-linux,
  aarch64-linux, and aarch64-darwin.
- `cargo check --offline -p zed -p remote_server --features visual-tests` passes
  with all six patches and the bundled-server compile-time variables set.
- `cargo test --offline -p terminal pixel_scroll_tracks_fractional_position_across_rows`
  passes (1 test).
- The test executable built by `cargo test --offline -p vim test_flash_jump`
  passes all 32 Flash tests when run from the patched Git checkout. The initial
  Nix-sandbox invocation stopped in shared setup because the source archive has
  no `.git` entry; `util::dev_repo_root` needs one to locate development assets.
  Running the same executable with the patched checkout as its working directory
  resolves that setup failure without changing source code.

This audit does not include a full release build, a separate musl build, or
interactive GUI/SSH smoke tests.
