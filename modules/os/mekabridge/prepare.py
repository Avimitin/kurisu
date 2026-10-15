"""Reconcile the bridge with meka's operator-managed configuration."""

import json
import os
from pathlib import Path
import re
import secrets
import sys
import tempfile
import tomllib

import tomlkit


def atomic_write(path, content):
    path = Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def telegram_settings(settings):
    """An unfinished setup is a skipped unit, not a failed daemon."""
    try:
        token = Path(settings["telegramToken"]).read_text().strip()
        if not re.fullmatch(r"[0-9]+:[A-Za-z0-9_-]{20,}", token):
            raise ValueError("Telegram bot token is empty or has an invalid format")
        values = tomllib.loads(Path(settings["telegramSettings"]).read_text())
        if set(values) - {"allowed_users", "allowed_chats"}:
            raise ValueError("Telegram settings accept only allowed_users and allowed_chats")
        for key in ("allowed_users", "allowed_chats"):
            ids = values.setdefault(key, [])
            if not isinstance(ids, list) or any(type(i) is not int or i == 0 for i in ids):
                raise ValueError(f"{key} must contain nonzero numeric Telegram IDs")
        if any(i < 0 for i in values["allowed_users"]):
            raise ValueError("allowed_users must contain positive Telegram user IDs")
        if not (values["allowed_users"] or values["allowed_chats"]):
            raise ValueError("Telegram allowlist is empty")
        return values
    except (OSError, ValueError):
        # Never include parser errors: operator files may contain credentials.
        print("mekabridge: setup pending; fill the Telegram token and allowlist files", file=sys.stderr)
        return None


def ensure_meka_token(settings):
    token = Path(settings["mekaToken"])
    token.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        fd = os.open(token, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        if not token.read_text().strip():
            raise ValueError("existing bridge API token is empty")
    else:
        with os.fdopen(fd, "w") as output:
            output.write(secrets.token_urlsafe(48) + "\n")


def sync_meka(settings, ready):
    path = Path(settings["mekaConfig"])
    previous = path.read_text()
    config = tomlkit.parse(previous)
    serve = config.setdefault("serve", tomlkit.table())
    tokens = serve.setdefault("tokens", tomlkit.aot())
    for index in reversed(range(len(tokens))):
        if tokens[index].get("token_file") == settings["mekaToken"]:
            del tokens[index]
    tokens.append(tomlkit.item({
        "description": "mekabridge",
        "token_file": settings["mekaToken"],
        "scopes": ["sessions:r", "sessions:w"],
    }))

    mcp = config.setdefault("mcp", tomlkit.table())
    servers = mcp.setdefault("servers", tomlkit.aot())
    for index in reversed(range(len(servers))):
        if servers[index].get("name") == "mekabridge":
            del servers[index]
    if ready:
        servers.append(tomlkit.item(settings["server"]))
        serve["stream_replay_events"] = max(4096, serve.get("stream_replay_events", 0))
    updated = tomlkit.dumps(config)
    if updated != previous:
        backup = path.with_name(path.name + ".before-mekabridge")
        if not backup.exists():
            atomic_write(backup, previous)
        atomic_write(path, updated)


def main():
    settings = json.loads(Path(sys.argv[1]).read_text())
    action = sys.argv[2]
    telegram = telegram_settings(settings)
    if action == "check":
        return 0 if telegram is not None else 1
    ensure_meka_token(settings)
    if action == "meka":
        sync_meka(settings, telegram is not None)
    elif action == "bridge":
        if telegram is None:
            return 1
        config = settings["bridge"]
        config["channels"] = {"telegram": [{
            "id": "telegram",
            "token_file": settings["telegramToken"],
            "admin_tools": False,
            **telegram,
        }]}
        atomic_write(settings["runtimeConfig"], tomlkit.dumps(config))
    else:
        raise ValueError("unknown preparation action")
    return 0


if __name__ == "__main__":
    sys.exit(main())
