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

FLOX_ENV_DIR="$(realpath -m "$FLOX_ENV_DIR")"
export FLOX_ENV_DIR
export FLOX_ENV_NAME="$(basename "$FLOX_ENV_DIR")"

if [[ -n "${FLOX_MANIFEST_PATH:-}" ]]; then
  FLOX_MANIFEST_PATH="$(realpath -m "$FLOX_MANIFEST_PATH")"
  export FLOX_MANIFEST_PATH
fi

if [[ ! -f "$FLOX_MANIFEST_PATH" ]]; then
  echo "ERROR: Flox manifest not found at $FLOX_MANIFEST_PATH" >&2
  exit 1
fi

resolve_included_env_dirs() {
  local manifest_dir="$1"
  local manifest_path="$2"

  awk '
    match($0, /dir[[:space:]]*=[[:space:]]*"([^"]+)"/, parts) {
      print parts[1]
    }
  ' "$manifest_path" | while IFS= read -r relative_dir; do
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

declare -A synced_envs=()

sync_env_recursive() {
  local env_dir="$(realpath -m "$1")"
  local env_name="$2"
  local manifest_path=""
  local included_env_dir=""
  local -a included_env_dirs=()

  if [[ -n "${synced_envs[$env_dir]:-}" ]]; then
    return
  fi
  synced_envs["$env_dir"]=1

  manifest_path="$(hybrid_ai_flox_manifest_path_for "$env_dir" || true)"
  if [[ -z "$manifest_path" ]]; then
    echo "ERROR: Flox manifest not found under $env_dir" >&2
    exit 1
  fi

  mapfile -t included_env_dirs < <(resolve_included_env_dirs "$env_dir" "$manifest_path")

  for included_env_dir in "${included_env_dirs[@]}"; do
    [[ -n "$included_env_dir" ]] || continue
    sync_env_recursive "$included_env_dir" "$(basename "$included_env_dir")"
  done

  sync_single_env "$env_dir" "$env_name"
}

for flox_dir in "$XDG_CONFIG_HOME/flox" "$XDG_CACHE_HOME/flox" "$XDG_DATA_HOME/flox"; do
  if [[ -e "$flox_dir" || -L "$flox_dir" ]] && [[ ! -w "$flox_dir" ]]; then
    echo "ERROR: Flox cache path is not writable: $flox_dir" >&2
    echo "Repair ownership first, for example:" >&2
    echo "  sudo chown -R \"$(id -un)\":\"$(id -gn)\" '$flox_dir'" >&2
    exit 1
  fi
done

sync_env_recursive "$FLOX_ENV_DIR" "$FLOX_ENV_NAME"

echo "Initialized and synced Flox environment at: $FLOX_ENV_DIR"