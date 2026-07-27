#!/usr/bin/env bash
#
# Convert Gram's live settings.jsonc into the Nix attribute set tracked here.
# Machine-local keys listed in blacklist.json are removed before conversion.
#
# Usage:
#   ./modules/hm/gram/sync.sh
#   ./modules/hm/gram/sync.sh --from-json FILE
#   GRAM_SETTINGS_SRC=FILE ./modules/hm/gram/sync.sh

set -euo pipefail

gram_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
blacklist_file="$gram_dir/blacklist.json"
out_file="$gram_dir/settings.nix"
default_src="${GRAM_SETTINGS_SRC:-$HOME/.config/gram/settings.jsonc}"

src=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-json | --src)
      if [[ $# -lt 2 ]]; then
        echo "gram-sync: $1 requires a file path" >&2
        exit 2
      fi
      src="$2"
      shift 2
      ;;
    --from-json=* | --src=*)
      src="${1#*=}"
      shift
      ;;
    -h | --help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "gram-sync: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done
src="${src:-$default_src}"

if [[ ! -f "$src" ]]; then
  echo "gram-sync: source settings not found: $src" >&2
  echo "  (set GRAM_SETTINGS_SRC or pass --from-json FILE)" >&2
  exit 1
fi
if [[ ! -f "$blacklist_file" ]]; then
  echo "gram-sync: blacklist not found: $blacklist_file" >&2
  exit 1
fi
if ! jq -e 'type == "array" and all(type == "string")' "$blacklist_file" >/dev/null 2>&1; then
  echo "gram-sync: $blacklist_file must be a JSON array of dot-path strings" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

stripped="$work/stripped.json"
filtered="$work/filtered.json"

# Gram writes JSONC, including comments and trailing commas. Reuse a parser from
# PATH when possible; otherwise build the one pinned by this flake.
if command -v pyjson5 >/dev/null 2>&1; then
  json5_parser=(pyjson5)
elif command -v json5 >/dev/null 2>&1; then
  json5_parser=(json5)
else
  repo_root="$(cd "$gram_dir/../../.." && pwd)"
  system="$(nix eval --impure --raw --expr builtins.currentSystem)"
  json5_package="$(
    nix build --no-link --print-out-paths \
      "path:$repo_root#legacyPackages.${system}.python3Packages.json5"
  )"
  json5_parser=("$json5_package/bin/pyjson5")
fi
"${json5_parser[@]}" --as-json "$src" > "$stripped"

if ! jq empty "$stripped" 2>/dev/null; then
  echo "gram-sync: $src is not valid JSONC" >&2
  exit 1
fi

# Sort and de-duplicate blacklist paths. If a parent path is present, discard
# its children so jq's delpaths never descends through an already removed key.
jq --slurpfile blacklist "$blacklist_file" '
  . as $settings
  | (($blacklist[0] // [])
      | map(split("."))
      | sort
      | reduce .[] as $path
          ({ kept: [], previous: null };
            if .previous != null
               and ($path | length) > (.previous | length)
               and ($path[0:(.previous | length)] == .previous)
            then .
            else .kept += [$path] | .previous = $path
            end)
      | .kept) as $paths
  | $settings
  | delpaths($paths)
' "$stripped" > "$filtered"

raw_nix="$work/settings.raw.nix"
nix-instantiate --eval --strict \
  --expr "builtins.fromJSON (builtins.readFile $filtered)" \
  > "$raw_nix"

if command -v nixfmt >/dev/null 2>&1; then
  nixfmt - < "$raw_nix" > "$out_file"
else
  cp "$raw_nix" "$out_file"
fi

echo "gram-sync: wrote $out_file (from $src)"
