# Zed patch audit

Audited on 2026-10-08 against Zed **1.22.0**, as packaged by nixpkgs
`7dd199b0e2993e37b4775ed66b1c291699608c9f`:

- Upstream source: `zed-industries/zed`, tag [`v1.22.0`](https://github.com/zed-industries/zed/releases/tag/v1.22.0).
- Nix source hash: `sha256-XdWQjtdkbSqyEP/c2bGycPFEHS37tonSzTeVxyK1AHw=`.
- Previous audit: 1.21.0. Compared both pinned source trees and reviewed the
  affected callers and implementations. All six patches remain necessary.
  Five patches retain their source changes; pixel scrolling now preserves the
  new `MouseInputMode` argument in terminal handlers and scroll callers,
  including the upstream tests and the read-only terminal view. Patch context
  and line numbers were regenerated in package order.

Apply patches in the order in `zed-editor.nix`. The remote server applies only
`zed-no-automatic-downloads.patch`; the editor additionally applies
`zed-local-remote-server.patch` when a bundled server is available.

| Patch | Reviewed behavior in 1.22.0 |
| --- | --- |
| `zed-no-automatic-downloads.patch` | The sole production `get_language_server_binary` caller still controls built-in LSP downloads. All four Node runtime initializers disable managed Node downloads while retaining configured paths and PATH lookup. Extension startup still loads the index without launching automatic installs or updates. Extension-provided LSP commands use a separate API; their PATH-only behavior is supplied by `zed-extensions-path-only.nix`. |
| `zed-extension-checksums.patch` | Both extension extraction paths write a SHA-256 receipt. Index rebuilds and cached entries classify receipt-bearing symlinks as installed extensions; unmarked symlinks remain development extensions. Receipts identify installation provenance; loading checks their format, not the current directory contents. |
| `zed-linux-system-notifications.patch` | Both agent notification paths retain visibility and notification-setting guards. Linux uses GPUI system notifications and application identity; other platforms retain popup windows. The GPUI Linux notification interface is unchanged. |
| `zed-pixel-scroll.patch` | The setting is connected through defaults, deserialization, VS Code import, runtime settings, and both scroll callers. Precise scrolling remains limited to ordinary scrollback, with overscan, drawing, and mouse coordinates aligned; alternate-screen and mouse-reporting paths keep their existing behavior. The new `LocalSelection` mode supports local scrollback without reporting input to the terminal; `ReportToTerminal` retains mouse reporting. A regression test covers both modes with precise input and excludes alternate-screen pixel scrolling. |
| `zed-flash-jump.patch` | Action registration, waiting-mode input, inclusive motions, viewport clipping, and overlay cleanup remain compatible. All `Motion::Jump` constructors supply the new field, and operator-stack clearing goes through UI cleanup. Search bounds and the existing Flash regression tests are retained. |
| `zed-local-remote-server.patch` | Returning no download URL still makes SSH fall through to local upload. The local provider returns the Nix-built archive after checking the target OS/architecture and file existence. The editor/server version assertion remains in place. |

Validation uses the pinned nixpkgs dependencies and Rust 1.98.1 on x86_64-linux:

- All six patches apply in package order with `patch --fuzz=0`, without offsets
  or rejected hunks. All 30 resulting files match the audited source tree.
- `rustfmt --check` passes for all 25 touched Rust files; `nixfmt --check` passes
  for `zed-editor.nix`; `git diff --check` passes.
- The actual x86_64-linux editor and bundled musl server derivations evaluate at
  1.22.0. Editor derivations without bundling also evaluate on x86_64-linux,
  aarch64-linux, and aarch64-darwin.

- The editor check phase now creates a `.git` marker so Zed's development
  asset lookup can find the source archive when running tests in the sandbox.

- On `henan-builder`, `cargo check --offline -p zed -p remote_server --features
  visual-tests` passes with all six patches and the bundled-server compile-time
  variables set.
- `cargo test --offline -p terminal pixel_scroll` passes both the fractional
  scrolling test and the new mouse-input-mode regression (2 tests).
- `cargo test --offline -p terminal test_local_selection` passes all three
  upstream tests for scrolling, hyperlink activation, and primary selection.

- `cargo test --offline -p vim test_flash_jump` passes all 32 Flash tests.
  The focused test derivation creates a `.git` marker before running the debug
  tests so `util::dev_repo_root` can find the development assets in the sandbox.

- The separate musl remote-server release build succeeds on `henan-builder`.
  After copying its packaged closure locally, the extracted binary reports
  1.22.0. `readelf` confirms no ELF interpreter, `DT_NEEDED`, `RPATH`, or `RUNPATH`.

Linux editor builds now use nixpkgs' `useMoldLinker` stdenv adapter and 16
release codegen units per crate while retaining upstream ThinLTO. A remote
Rust 1.98.1 smoke build with ThinLTO and 16 codegen units succeeds and its ELF
`.comment` section identifies mold 2.42.1. The editor build runs with
`--max-jobs 1 --cores 256`, which supplies Cargo with `-j 256`; Nix's job count
controls simultaneous derivations, while Cargo's count controls crate builds.

The editor release build succeeds on `henan-builder`: Cargo's release build
finishes in 5m 37s, and the packaged nextest suite passes 92 tests with 1 skipped.
The check phase, including compilation with `visual-tests`, takes 4m 36s. The
install version check reports 1.22.0. The installed editor's ELF `.comment`
section confirms mold 2.42.1 and Rust 1.98.1.

The project was synced to `/root/kurisu-zed-1.22.0` and built there with:

```sh
nix build path:/root/kurisu-zed-1.22.0#legacyPackages.x86_64-linux.zed-editor \
  --no-update-lock-file --max-jobs 1 --cores 256 --out-link result-zed -L
```

The resulting editor closure was copied back with:

```sh
nix copy --from ssh://henan-builder --no-check-sigs \
  /nix/store/68jisd3bdjyjvxfs61x6wvvvwjnd2pyj-zed-editor-1.22.0
nix build --offline --max-jobs 0 --builders '' --no-update-lock-file \
  .#legacyPackages.x86_64-linux.zed-editor --out-link zed-result
```

`--no-check-sigs` permits this authenticated builder's unsigned local outputs.
The local realization succeeds with builds disabled;
`./zed-result/bin/zeditor --version` reports 1.22.0. Its 1,719,825,504-byte closure
includes the bundled portable server. Interactive GUI, desktop-notification
delivery, and live SSH upload were not exercised.
