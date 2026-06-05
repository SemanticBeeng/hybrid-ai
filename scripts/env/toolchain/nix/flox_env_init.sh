#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

use_nix_daemon
ensure_nix_bind_mount
require_nix_daemon_socket

FLOX_ENV_DIR="${FLOX_ENV_DIR:-$PROJECT_ROOT/env/hybrid-ai}"
FLOX_ENV_NAME="${FLOX_ENV_NAME:-$(basename "$FLOX_ENV_DIR")}"
FLOX_MANIFEST_PATH="${FLOX_MANIFEST_PATH:-$FLOX_ENV_DIR/manifest.toml}"
FLOX_DISABLE_METRICS=true

FLOX_BIN=""
if command -v flox >/dev/null 2>&1; then
  FLOX_BIN="$(command -v flox)"
elif [[ -x "$FLOX_WRAPPER_BIN" ]]; then
  FLOX_BIN="$FLOX_WRAPPER_BIN"
fi

if [[ -z "$FLOX_BIN" ]]; then
  echo "ERROR: flox is required but not installed or not in PATH." >&2
  echo "Run scripts/env/toolchain/nix/flox_install.sh first." >&2
  exit 1
fi

if [[ ! -f "$FLOX_MANIFEST_PATH" ]]; then
  echo "ERROR: Flox manifest not found at $FLOX_MANIFEST_PATH" >&2
  exit 1
fi

flox_env=(
  "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
  "XDG_CACHE_HOME=$XDG_CACHE_HOME"
  "XDG_DATA_HOME=$XDG_DATA_HOME"
  "HOME=$HOME"
  "FLOX_DISABLE_METRICS=$FLOX_DISABLE_METRICS"
)

resolve_included_env_dirs() {
  local manifest_dir
  manifest_dir="$(dirname "$FLOX_MANIFEST_PATH")"

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
  local manifest_path="$env_dir/manifest.toml"

  if [[ ! -f "$manifest_path" ]]; then
    echo "ERROR: Flox manifest not found at $manifest_path" >&2
    exit 1
  fi

  if [[ -d "$env_dir/.flox" ]] && [[ ! -w "$env_dir/.flox" ]]; then
    echo "ERROR: managed Flox state is not writable: $env_dir/.flox" >&2
    echo "Repair ownership first, for example:" >&2
    echo "  sudo chown -R \"$(id -un)\":\"$(id -gn)\" '$env_dir/.flox'" >&2
    exit 1
  fi

  if [[ ! -f "$env_dir/.flox/env.json" ]]; then
    env "${flox_env[@]}" "$FLOX_BIN" init -d "$env_dir" -n "$env_name" --no-auto-setup
  fi

  env "${flox_env[@]}" "$FLOX_BIN" edit -d "$env_dir" -f "$manifest_path"
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

echo "Initialized and synced Flox environment at: $FLOX_ENV_DIR"