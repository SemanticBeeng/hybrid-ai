#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$project_root/scripts/env/toolchain/common.sh"

use_nix_daemon
ensure_nix_bind_mount
require_nix_daemon_socket

FLOX_BIN="$(require_flox_bin || true)"
if [[ -z "$FLOX_BIN" ]]; then
  echo "Run scripts/env/toolchain/nix/flox_install.sh first." >&2
  exit 1
fi

if [[ ! -f "$FLOX_MANIFEST_PATH" ]]; then
  echo "ERROR: Flox manifest not found at $FLOX_MANIFEST_PATH" >&2
  exit 1
fi

resolve_included_env_dirs() {
  local manifest_dir
  manifest_dir="$FLOX_ENV_DIR"

  awk '
    match($0, /dir[[:space:]]*=[[:space:]]*"([^"]+)"/, parts) {
      print parts[1]
    }
  ' "$FLOX_MANIFEST_PATH" | while IFS= read -r relative_dir; do
    [[ -n "$relative_dir" ]] || continue
    realpath -m "$manifest_dir/$relative_dir"
  done
}

sync_single_env() {
  local env_dir="$1"
  local env_name="$2"
  local manifest_path=""

  manifest_path="$(hybrid_ai_flox_manifest_path_for "$env_dir" || true)"

  if [[ -z "$manifest_path" ]]; then
    echo "ERROR: Flox manifest not found under $env_dir" >&2
    exit 1
  fi

  if [[ -d "$env_dir/.flox" ]] && [[ ! -w "$env_dir/.flox" ]]; then
    echo "ERROR: managed Flox state is not writable: $env_dir/.flox" >&2
    echo "Repair ownership first, for example:" >&2
    echo "  sudo chown -R \"$(id -un)\":\"$(id -gn)\" '$env_dir/.flox'" >&2
    exit 1
  fi

  if [[ ! -f "$env_dir/.flox/env.json" && ! -f "$env_dir/.flox/env/manifest.toml" ]]; then
    hybrid_ai_flox_tool_env "$FLOX_BIN" init -d "$env_dir" -n "$env_name" --no-auto-setup
  fi

  hybrid_ai_flox_tool_env "$FLOX_BIN" edit -d "$env_dir" -f "$manifest_path"
}

for flox_dir in "$XDG_CONFIG_HOME/flox" "$XDG_CACHE_HOME/flox" "$XDG_DATA_HOME/flox"; do
  if [[ -e "$flox_dir" || -L "$flox_dir" ]] && [[ ! -w "$flox_dir" ]]; then
    echo "ERROR: Flox cache path is not writable: $flox_dir" >&2
    echo "Repair ownership first, for example:" >&2
    echo "  sudo chown -R \"$(id -un)\":\"$(id -gn)\" '$flox_dir'" >&2
    exit 1
  fi
done

while IFS= read -r included_env_dir; do
  [[ -n "$included_env_dir" ]] || continue
  sync_single_env "$included_env_dir" "$(basename "$included_env_dir")"
done < <(resolve_included_env_dirs)

sync_single_env "$FLOX_ENV_DIR" "$FLOX_ENV_NAME"

if [[ -n "$(resolve_included_env_dirs)" ]]; then
  hybrid_ai_flox_tool_env "$FLOX_BIN" include upgrade -d "$FLOX_ENV_DIR"
  sync_single_env "$FLOX_ENV_DIR" "$FLOX_ENV_NAME"
fi

echo "Initialized and synced Flox environment at: $FLOX_ENV_DIR"