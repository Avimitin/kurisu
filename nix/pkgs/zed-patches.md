# Zed patch audit

Audited on 2026-11-14 against Zed **1.27.0**, as packaged by nixpkgs
`2074cc672349f14240fb7ea90d509e0b643e9dd4`:

- Upstream source: `zed-industries/zed`, tag [`v1.27.0`](https://github.com/zed-industries/zed/releases/tag/v1.27.0).
- Nix source hash: `sha256-pYT/+23XPsXpkErUVIqlKS3cKPyE7LMtj6rnSl+NqXY=`.
- Previous audit: 1.25.3. Compared the pinned source trees and reviewed affected
  implementations and callers. All six patches remain necessary. Adapted pixel
  scrolling and its tests to `ScrollEvent`, and preserved upstream's new
  context-aware secondary-modifier checks. The other changes refresh patch
  context and indexes; the local remote-server patch remains byte-for-byte
  unchanged.

Apply patches in the order in `zed-editor.nix`. The remote server applies only
`zed-no-automatic-downloads.patch`; the editor additionally applies
`zed-local-remote-server.patch` when a bundled server is available.

| Patch | Reviewed behavior in 1.27.0 |
| --- | --- |
| `zed-no-automatic-downloads.patch` | The sole production `get_language_server_binary` caller still controls built-in LSP downloads despite the upstream LSP-store refactor. Explicit binaries, PATH lookup, and worktree trust checks remain intact. All four Node runtime initializers disable managed Node downloads; upstream's isolated npm working directory and executable lookup are preserved. Extension startup loads the index without launching automatic installs or updates. Extension-provided LSP commands use a separate API; their PATH-only behavior is supplied by `zed-extensions-path-only.nix`. |
| `zed-extension-checksums.patch` | Both extension extraction paths still write a SHA-256 receipt. Index rebuilds and cached entries classify receipt-bearing symlinks as installed extensions; unmarked symlinks remain development extensions. The filesystem helper `is_dev_extension_dir` remains distinct from upstream's indexed `is_dev_extension` query. Upstream's batched language registration changes are preserved. Receipts identify installation provenance; loading checks their format, not the current directory contents. |
| `zed-linux-system-notifications.patch` | Both agent notification paths retain visibility and notification-setting guards, including the conversation title override. Linux uses GPUI system notifications and application identity; other platforms retain popup windows. The GPUI notification API and Linux notification implementation remain compatible. |
| `zed-pixel-scroll.patch` | Upstream now delivers pointer and touch scrolling through `ScrollEvent` and `on_scroll`; the patch and added tests use the new event type. Modifier checks retain the new `secondary(cx)` API. Defaults, deserialization, VS Code import, runtime settings, and scroll callers remain connected. Precise scrolling stays limited to ordinary scrollback, with overscan, rendering, hyperlinks, and mouse coordinates aligned. Alternate-screen and terminal mouse-reporting paths retain their existing behavior. `LocalSelection` still permits local scrollback without terminal input reports. Replacing display-only output clears fractional state and queued events. |
| `zed-flash-jump.patch` | Action registration, waiting-mode input, inclusive motions, viewport clipping, and overlay cleanup remain compatible. All `Motion::Jump` constructors supply the new field, and operator-stack clearing goes through UI cleanup. Upstream's Helix paste-mode fix and platform-aware key handling are preserved. Search bounds and all 32 Flash regression tests are retained. |
| `zed-local-remote-server.patch` | The patched auto-update implementation is unchanged upstream. Returning no download URL still makes SSH fall through to local upload. Upstream's SSH argument and environment-probing changes preserve that flow. The local provider checks the target OS/architecture and archive existence. The editor/server version assertion remains in place. |

Validation uses the pinned nixpkgs dependencies and Rust 1.99.1 on x86_64-linux:

- All six patches apply in package order with `patch --fuzz=0`, without offsets
  or rejected hunks. All 30 resulting files match the audited source tree.
- `rustfmt --check` passes for all 25 touched Rust files; `nixfmt --check`
  passes for `zed-editor.nix` and `zed-remote-server.nix`; `git diff --check`
  passes.
- The version guard rejects unaudited editor versions and mismatched bundled
  servers. The editor and bundled musl server derivations evaluate at 1.27.0.
  Editor derivations without bundling also evaluate on x86_64-linux,
  aarch64-linux, and aarch64-darwin. These are evaluation checks, not builds on
  the ARM platforms.
- The separate musl remote-server release build succeeds on `henan-builder`
  (12m 12s in Cargo). Its extracted, packaged binary reports 1.27.0.
  `llvm-readelf` confirms no ELF interpreter, `DT_NEEDED`, `RPATH`, or `RUNPATH`.
- The editor release build succeeds on `henan-builder` (5m 6s in Cargo).
  The packaged nextest suite passes **96 tests, with 2 skipped**. Its check
  phase, including compilation with `visual-tests`, takes 4m 55s. The install
  version check reports 1.27.0. The installed editor's ELF `.comment` section
  confirms Rust 1.99.1 and mold 3.0.0.
- All **9 terminal tests and 32 Flash tests pass** in the focused debug
  derivation (4m 59s total build phase, with `-j 128`). Its result is
  `/nix/store/ynigj84z5vjlm1327vxcz6yqh749land-zed-patch-tests-1.27.0`.

The new nixpkgs `cargoUseSystemLibs` hook initially prevented the isolated musl
server from building: it forced `zstd-sys` to find a system `libzstd.pc` for both
host and target compilations. `zed-remote-server.nix` now sets
`dontCargoUseSystemLibs = true` so its native dependencies continue to compile
from the pinned Cargo sources. The editor retains its nixpkgs system libraries.

Linux editor builds retain `useMoldLinker`, 16 release codegen units per crate,
and upstream ThinLTO. The editor check phase creates a `.git` marker so Zed's
asset lookup works with the source archive in the sandbox.

All compilation and Rust tests ran on `henan-builder`. The project was synced
to `/root/kurisu-zed-1.27.0-audit` and built with:

```sh
nix build path:/root/kurisu-zed-1.27.0-audit#legacyPackages.x86_64-linux.zed-editor \
  --no-update-lock-file --max-jobs 1 --cores 256 \
  --out-link /root/zed-1.27.0-audit-result -L
```

The focused debug test derivation at `/root/zed-focused-tests-1.27.0.nix` reuses
the editor's pinned source, all six patches, vendored dependencies, build inputs,
and bundled-server variables. It disables debug symbols and incremental
compilation, creates the `.git` asset marker, and runs:

```sh
cargo test --offline -j "$NIX_BUILD_CORES" -p terminal pixel_scroll
cargo test --offline -j "$NIX_BUILD_CORES" -p terminal test_local_selection
cargo test --offline -j "$NIX_BUILD_CORES" -p terminal test_replace_display_output
cargo test --offline -j "$NIX_BUILD_CORES" -p vim test_flash_jump
```

The built editor is
`/nix/store/j39hpi5zg71rway390aramdc2r3gbn9p-zed-editor-1.27.0`, with bundled server
`/nix/store/1r2aknhfaihrbzbza9ksy6l5ybqnp224-zed-remote-server-1.27.0`.
The repository evaluates to the same derivations as these validated outputs.

Build and test logs are retained on the builder at
`/root/zed-1.27.0-audit-build.log` and `/root/zed-1.27.0-audit-tests.log`; the
server version and ELF checks are in `/root/zed-1.27.0-audit-server-check.log`.
Interactive GUI, desktop-notification delivery, and live SSH server upload are
not exercised by these checks.
