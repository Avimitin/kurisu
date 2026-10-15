# meka container and Telegram bridge

`default.nix` declares the NixOS guest. `meka.nspawn` declares its host mounts and
port forwarding. nginx serves mekadsh and proxies meka's API on host port 58964.
The bridge polls Telegram over outbound HTTPS and exposes MCP only on the guest's
loopback port 9100.

The bridge is pinned to 0.18.2, compatible with the deployed meka 0.68.0 and
mekadsh frontend. Bridge 0.19 and newer require meka 0.71 or newer; that upgrade
also requires migrating mekadsh to the changed discovery, history and schedule APIs.

The host needs `systemd-networkd` for the guest's DHCP and NAT. Enable the container
at boot with `sudo systemctl enable --now systemd-nspawn@meka.service`.

## Finish Telegram setup

Create a bot using Telegram's @BotFather (`/newbot`) and find your numeric Telegram
user ID. On the host, edit these root-only files:

```sh
sudoedit /etc/mekabridge/telegram-token
sudoedit /etc/mekabridge/telegram.toml
```

The token file contains only the bot token on one line. The TOML file contains:

```toml
allowed_users = [123456789] # Replace with your numeric user ID.
allowed_chats = []
```

Then restart both guest services:

```sh
sudo systemctl -M meka restart mekabridge.service meka.service
sudo systemctl -M meka status mekabridge.service meka.service
sudo systemd-run --machine=meka --pipe --wait --collect \
  /run/current-system/sw/bin/mekabridge \
  --config /run/mekabridge/config.toml doctor
```

Open the bot in Telegram, press Start, and send it a message. The bot cannot
initiate your first conversation. No Telegram API calls are made while setup is
empty. The bridge service is skipped until both a token and an allowlist exist;
meka's web sessions remain usable during that time.

After setup, meka treats the bridge as a required MCP server. A bridge outage then
blocks turns until it reconnects, including web sessions on the same backend.
To disable Telegram again, empty the token file and restart both services.

This guest sets the bridge to `workspace` permission, with writes confined to
`/srv/meka-workspace` and moderation tools disabled. The workspace persists
on the host at `/var/lib/meka-workspace`. It must be outside meka's private data
and config directories: meka rejects their descendants as writable roots.
The reusable module defaults to `read` permission.
The bridge owns one persistent meka session shared by all allowed Telegram
conversations.
`allowed_users` admits DMs only. Adding a group to `allowed_chats` admits everyone
in that group. For group history, disable bot privacy mode through @BotFather and
re-add the bot; groups otherwise wake the agent on mentions and replies.

## Configuration and persistence

- `modules/os/mekabridge/default.nix`: service, permissions, ports, and runtime paths.
- `/etc/mekabridge/`: host-managed Telegram token and allowlists, mounted read-only.
- `/var/lib/mekabridge/`: host-persistent bridge database and attachments.
- `/var/lib/meka/`: host-persistent meka database, accounts, profiles, and config.
- `/var/lib/meka-workspace/`: host storage mounted at the guest's `/srv/meka-workspace/`.
- `/var/lib/meka/config/mekabridge-token`: automatically generated internal API token.
- `/run/mekabridge/config.toml`: generated bridge configuration, containing token paths.

meka reads `/var/lib/meka/config/config.toml`, initially seeded from `/etc/meka/config.toml`.
Startup reconciles only the bridge API token and the MCP server named `mekabridge`,
preserving provider settings and other MCP servers. The original configuration is
saved once as `config.toml.before-mekabridge`. Do not put credentials in Nix files.

`kurisu.os.mekabridge.permission` is reconciled with the existing bridge session
at startup. `workingDirectory` supplies the directory for new sessions; move an
existing session with meka's session API when changing it.

## Chat and worker profiles

The persistent config uses `telegram-chat` as the default for new sessions and
the bridge's existing session is pinned to it. Both profiles use the `deepseek`
account and `deepseek-flash` model:

| Profile | Effort | Purpose |
|---------|--------|---------|
| `telegram-chat` | `low` | Quick replies and background task delegation |
| `deepseek` | `max` | Complex work delegated to a worker |

Existing sessions keep their recorded profile. Changing `deepseek` therefore
also changes the effort of existing web sessions using that profile.

The operator-managed `/var/lib/meka/config/config.toml` enables:

```toml
[subagents]
agent_chosen_profile = true
disabled_tools = [
  "mcp__mekabridge__message_send",
  "mcp__mekabridge__file_send",
  "mcp__mekabridge__message_react",
  "mcp__mekabridge__message_edit",
  "mcp__mekabridge__message_delete",
]

[background]
enabled = true
max_tasks = 2
```

Workers can read bridge history and attachments and return reports; the chat
agent sends replies. `telegram-chat.md` declares the routing instructions and is
installed at startup as `config/instructions/70-telegram-chat.md`. They apply to
root sessions using `telegram-chat`; sub-agents do not inherit them by default.
Background tasks cannot survive a meka process restart and are then reported as
interrupted. Routing is chosen by the agent from these instructions.

Profiles and delegation settings live in the persistent config, outside the Nix
store. To change the worker effort, run:

```sh
sudo systemd-run --machine=meka --pipe --wait --collect \
  --setenv=MEKA_CONFIG_DIR=/var/lib/meka/config \
  --setenv=MEKA_DATA_DIR=/var/lib/meka \
  /run/current-system/sw/bin/meka profile set deepseek effort max
sudo systemctl -M meka restart meka.service
```

## Build and update

For first installation, follow the rootfs instructions in `meka.nspawn` and
provision its bind-mount directories before starting the container. Copy
`telegram.toml.example` to `/etc/mekabridge/telegram.toml` and create an empty,
mode-0600 `/etc/mekabridge/telegram-token` file.

For an existing guest, build and copy a new system closure without replacing its
rootfs or persistent state:

```sh
nix build .#nixosConfigurations.meka.config.system.build.toplevel -o result-meka
guest_system=$(readlink -f result-meka)
sudo nix --extra-experimental-features nix-command copy --no-check-sigs \
  --to 'local?root=/var/lib/machines/meka' "$guest_system"
sudo systemd-run --machine=meka --pipe --wait --collect \
  /run/current-system/sw/bin/nix-env \
  -p /nix/var/nix/profiles/system --set "$guest_system"
sudo systemd-run --machine=meka --pipe --wait --collect \
  "$guest_system/bin/switch-to-configuration" switch
```

The copy accepts unsigned outputs because this closure was built locally from
the repository; it does not change the guest's signature policy.

Changes to `meka.nspawn` must also be installed to `/etc/systemd/nspawn/meka.nspawn`
on the host and require a container restart. Back up `/var/lib/meka` and
`/var/lib/mekabridge` before upgrades that migrate their databases.

Upstream documentation: [mekabridge](https://github.com/k4yt3x/mekabridge/tree/master/docs/book/src).
