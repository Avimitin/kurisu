#!/usr/bin/env bash
#
# zed/sync.sh — convert Zed's live settings.json into a Nix attribute set
# tracked in this repo.
#
# Pipeline:
#   ~/.config/zed/settings.json
#     --(strip JSON5 comments)--> plain JSON
#     --(jq: drop blacklisted keys)--> filtered JSON
#     --(nix-instantiate --eval)--> Nix attribute set
#     --(nixfmt, if available)--> modules/hm/zed/settings.nix
#
# The blacklisted keys (machine-local state Zed rewrites behind your back,
# such as ssh_connections) live in modules/hm/zed/blacklist.json as an array
# of dot-paths, e.g. ["ssh_connections", "agent.foo"].
#
# Usage (run from the repo root, or anywhere — paths resolve from the script):
#   ./modules/hm/zed/sync.sh                       # sync from ~/.config/zed/settings.json
#   ./modules/hm/zed/sync.sh --from-json FILE      # sync from an explicit JSON file
#   ./modules/hm/zed/sync.sh --src FILE            # alias of --from-json
#   ZED_SETTINGS_SRC=... ./modules/hm/zed/sync.sh  # override source via env
#
# Then in modules/hm/zed.nix:
#   userSettings = import ./zed/settings.nix;

set -euo pipefail

# Resolve repo paths relative to this script so it can be run from anywhere.
# The script lives inside the zed module directory, so that is also zed_dir.
zed_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
blacklist_file="$zed_dir/blacklist.json"
out_file="$zed_dir/settings.nix"
default_src="${ZED_SETTINGS_SRC:-$HOME/.config/zed/settings.json}"

src=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-json|--src)
      src="$2"
      shift 2
      ;;
    --from-json=*|--src=*)
      src="${1#*=}"
      shift
      ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "zed-sync: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done
src="${src:-$default_src}"

if [[ ! -f "$src" ]]; then
  echo "zed-sync: source settings not found: $src" >&2
  echo "  (set ZED_SETTINGS_SRC or pass --from-json FILE)" >&2
  exit 1
fi
if [[ ! -f "$blacklist_file" ]]; then
  echo "zed-sync: blacklist not found: $blacklist_file" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

stripped="$work/stripped.json"
filtered="$work/filtered.json"

# 1. Strip JSON5-ish comments so plain jq can parse Zed's settings.json.
#    Zed prepends a `// ...` header and tolerates // and /* */ comments.
#    This only removes comments outside of string literals for the common
#    cases Zed actually emits; it is intentionally conservative.
strip_comments() {
  local in="$1" out="$2"
  # Remove /* ... */ block comments and // ... line comments, then drop
  # lines that end up empty. Done in sed to avoid extra dependencies.
  sed -E \
    -e 's#/\*.*\*/##g' \
    -e 's#//[^\n"]*$##' \
    "$in" > "$out"
}

strip_comments "$src" "$stripped"

# Bail out early with a clear message if jq still can't parse it.
if ! jq empty "$stripped" 2>/dev/null; then
  echo "zed-sync: $src is not valid JSON even after stripping comments." >&2
  echo "  Inspect: $stripped" >&2
  exit 1
fi

# 2. Drop blacklisted keys. blacklist.json is an array of dot-paths such as
#    "ssh_connections" or "agent.tool_permissions" (use dots to descend into
#    nested objects). Validate it first so a typo gives a clear message instead
#    of a cryptic --slurpfile error.
if ! jq -e 'type == "array" and all(type == "string")' "$blacklist_file" >/dev/null 2>&1; then
  echo "zed-sync: $blacklist_file must be a JSON array of strings, e.g." >&2
  echo '  ["ssh_connections", "agent.tool_permissions"]' >&2
  exit 1
fi
#    Paths are sorted and de-duplicated: if both a parent and a child are
#    blacklisted (e.g. "agent" and "agent.tool_permissions"), the child is a
#    no-op and delpaths would otherwise error trying to descend into the key
#    the parent already removed.
jq --slurpfile bl "$blacklist_file" '
  . as $settings
  | ( ($bl[0] // [])
      | map(split("."))
      | sort
      | reduce .[] as $p
          ({ kept: [], prev: null };
            if .prev != null
               and ($p | length) > (.prev | length)
               and ($p[0:(.prev | length)] == .prev)
            then .
            else .kept += [$p] | .prev = $p end)
      | .kept ) as $paths
  | $settings
  | delpaths($paths)
' "$stripped" > "$filtered"

# 3. Materialise the filtered JSON as a Nix attribute set via nix-instantiate.
#    --strict forces deep evaluation so the whole tree is printed. $filtered is
#    an absolute path under mktemp (clean ASCII), so it parses as a Nix path
#    literal without any escaping.
tmp_nix="$work/settings.raw.nix"
nix-instantiate --eval --strict \
  --expr "builtins.fromJSON (builtins.readFile $filtered)" \
  > "$tmp_nix"

# 4. Format with nixfmt if it is on PATH; otherwise keep raw eval output.
if command -v nixfmt >/dev/null 2>&1; then
  nixfmt - < "$tmp_nix" > "$out_file"
else
  cp "$tmp_nix" "$out_file"
fi

echo "zed-sync: wrote $out_file (from $src)"
