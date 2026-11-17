# egui askpass

A compact SSH dialog for PINs, passwords, and security-key touch prompts.

## Build and preview

```sh
nix build github:Avimitin/kurisu#egui-askpass
nix run github:Avimitin/kurisu#egui-askpass -- --demo
```

## Use with SSH

After building, set the helper in your shell.

Bash/Zsh:

```sh
export SSH_ASKPASS="$(realpath result/bin/egui-askpass)"
```

Fish:

```fish
set -gx SSH_ASKPASS (realpath result/bin/egui-askpass)
```

Then connect:

```sh
env SSH_ASKPASS_REQUIRE=force ssh user@host
```

For agent prompts, also set the agent service's `SSH_ASKPASS` to the helper's
absolute path. See the [NixOS configuration](../../../machines/nixos/thinkbook13/desktop.nix)
for the SSH and GCR settings. Existing shells need their environment refreshed
after switching helpers.

Click **Confirm** or press **Enter** to submit; use **Cancel** or **Escape** to
dismiss the dialog. Dismissing a touch prompt does not cancel SSH authentication.

The dialog names the process that launched the helper. Agent requests show
the agent's name; the originating SSH client is unavailable.
Hover over the key request message to see the available key details.

Depending on OpenSSH's prompt handling, touch requests may remain in the terminal
or the dialog may close before the touch. Connection results appear in SSH.
