# Zed patch audit

Audited on 2026-10-26 against Zed **1.25.3**, as packaged by nixpkgs
`674a2028661e550a97400c1cc992b9cca9a668a1`:

- Upstream source: `zed-industries/zed`, tag [`v1.25.3`](https://github.com/zed-industries/zed/releases/tag/v1.25.3).
- Nix source hash: `sha256-jkaDP0sIyzMQDvT9IIbFe3KeMxcPeC+8vN5imwLzpAQ=`.
- Previous audit: 1.22.0. Compared the pinned source trees and reviewed affected
  implementations and callers. All six patches remain necessary. Rebased the
  checksum helper around a new upstream method, adapted notification and
  terminal-rendering context, and reset pixel scrolling when display-only
  terminal output is replaced. Other changes refresh patch context and indexes;
  the local remote-server patch remains byte-for-byte unchanged.

Apply patches in the order in `zed-editor.nix`. The remote server applies only
`zed-no-automatic-downloads.patch`; the editor additionally applies
`zed-local-remote-server.patch` when a bundled server is available.

| Patch | Reviewed behavior in 1.25.3 |
| --- | --- |
| `zed-no-automatic-downloads.patch` | The sole production `get_language_server_binary` caller still controls built-in LSP downloads. All four Node runtime initializers disable managed Node downloads while retaining configured paths and PATH lookup. Extension startup still loads the index without launching automatic installs or updates. Extension-provided LSP commands use a separate API; their PATH-only behavior is supplied by `zed-extensions-path-only.nix`. |
| `zed-extension-checksums.patch` | The filesystem helper is now named `is_dev_extension_dir` to avoid colliding with upstream's new public `is_dev_extension(&self, extension_id)` query, which reads the indexed flag rather than inspecting the filesystem. Both extension extraction paths write a SHA-256 receipt. Index rebuilds and cached entries classify receipt-bearing symlinks as installed extensions; unmarked symlinks remain development extensions. Receipts identify installation provenance; loading checks their format, not the current directory contents. |
| `zed-linux-system-notifications.patch` | Both agent notification paths retain visibility and notification-setting guards. Linux uses GPUI system notifications and application identity; other platforms retain popup windows. The conversation notification keeps upstream's new title override. The GPUI Linux notification interface is unchanged. |
| `zed-pixel-scroll.patch` | The setting is connected through defaults, deserialization, VS Code import, runtime settings, and both scroll callers. Precise scrolling remains limited to ordinary scrollback, with overscan, drawing, and mouse coordinates aligned; alternate-screen and mouse-reporting paths keep their existing behavior. The `LocalSelection` mode supports local scrollback without reporting input to the terminal; `ReportToTerminal` retains mouse reporting. The new `replace_display_output` path clears fractional scroll state along with queued events, with a regression test. Rendering preserves upstream's move of background painting into the rounded terminal container. Existing regression coverage for both mouse modes and alternate-screen exclusion is retained. |
| `zed-flash-jump.patch` | Action registration, waiting-mode input, inclusive motions, viewport clipping, and overlay cleanup remain compatible. All `Motion::Jump` constructors supply the new field, and operator-stack clearing goes through UI cleanup. Search bounds and the existing Flash regression tests are retained. |
| `zed-local-remote-server.patch` | Returning no download URL still makes SSH fall through to local upload. The local provider returns the Nix-built archive after checking the target OS/architecture and file existence. The editor/server version assertion remains in place. |

Validation uses the pinned nixpkgs dependencies and Rust 1.99.0 on x86_64-linux:

- All six patches apply in package order with `patch --fuzz=0`, without offsets
  or rejected hunks. All 30 resulting files match the audited source tree.
- `rustfmt --check` passes for all 25 touched Rust files; `nixfmt --check`
  passes for `zed-editor.nix`; `git diff --check` passes.
- The actual editor and bundled musl server derivations evaluate at 1.25.3.
  Editor derivations without bundling also evaluate on x86_64-linux,
  aarch64-linux, and aarch64-darwin.

- The separate musl remote-server release build succeeds on `henan-builder`
  (12m 47s in Cargo). Its copied, extracted binary reports 1.25.3. `readelf`
  confirms no ELF interpreter, `DT_NEEDED`, `RPATH`, or `RUNPATH`.
- The editor release build succeeds on `henan-builder` (5m 15s in Cargo).
  The packaged nextest suite passes **91 tests, with 2 skipped**. Its check
  phase, including compilation with `visual-tests`, takes 5m 2s. The install
  version check reports 1.25.3. The installed editor's ELF `.comment` section
  confirms Rust 1.99.0 and mold 3.0.0.

The focused debug test derivation on `henan-builder` reuses the editor's pinned
source, all six patches, vendored dependencies, build inputs, and bundled-server
variables. It disables debug symbols and incremental compilation, creates the
`.git` asset marker, and runs:

```sh
cargo test --offline -p terminal pixel_scroll
cargo test --offline -p terminal test_local_selection
cargo test --offline -p terminal test_replace_display_output
cargo test --offline -p vim test_flash_jump
```

All **9 terminal tests and 32 Flash tests pass**. The pixel-scroll tests include
the new output-replacement regression. Cargo receives `-j 256` in each command.
The derivation is retained at `/root/zed-focused-tests-1.25.3.nix`; its result is
`/nix/store/2dcm5k36d91i0gv3y4wiq3vg4mypicwy-zed-patch-tests-1.25.3`.
Build and test logs remain on the builder at `/root/zed-1.25.3-build.log` and
`/root/zed-1.25.3-tests.log`.

Linux editor builds retain `useMoldLinker`, 16 release codegen units per crate,
and upstream ThinLTO. The editor check phase creates a `.git` marker so Zed's
asset lookup works with the source archive in the sandbox.

The project was synced to `/root/kurisu-zed-1.25.3` and built there with:

```sh
nix build path:/root/kurisu-zed-1.25.3#legacyPackages.x86_64-linux.zed-editor \
  --no-update-lock-file --max-jobs 1 --cores 256 --out-link result-zed -L
```

The resulting editor closure was copied back using the existing SSH
ControlMaster, then realized locally with builds disabled:

```sh
NIX_SSHOPTS="-S $HOME/.ssh/socket/10.255.90.182-22-root -o ControlMaster=no -o BatchMode=yes" \
  nix copy --from ssh://henan-builder --no-check-sigs \
    /nix/store/35wkb4s73j0q962fqxj8dig8dx6d02w5-zed-editor-1.25.3
nix build --offline --max-jobs 0 --builders '' --no-update-lock-file \
  .#legacyPackages.x86_64-linux.zed-editor --out-link zed-result
```

`--no-check-sigs` permits this authenticated builder's unsigned local outputs.
`./zed-result/bin/zeditor --version` reports 1.25.3. Its 1,671,737,192-byte closure
includes the bundled portable server. No Zed compilation ran locally.
Interactive GUI, desktop-notification delivery, and live SSH server upload were
not exercised.
