#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

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
  echo "Run scripts/env/install_flox.sh first." >&2
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

for flox_dir in "$XDG_CONFIG_HOME/flox" "$XDG_CACHE_HOME/flox" "$XDG_DATA_HOME/flox"; do
  if [[ -e "$flox_dir" || -L "$flox_dir" ]] && [[ ! -w "$flox_dir" ]]; then
    echo "ERROR: Flox cache path is not writable: $flox_dir" >&2
    echo "Repair ownership first, for example:" >&2
    echo "  sudo chown -R \"$(id -un)\":\"$(id -gn)\" '$flox_dir'" >&2
    exit 1
  fi
done

if [[ -d "$FLOX_ENV_DIR/.flox" ]] && [[ ! -w "$FLOX_ENV_DIR/.flox" ]]; then
  echo "ERROR: managed Flox state is not writable: $FLOX_ENV_DIR/.flox" >&2
  echo "Repair ownership first, for example:" >&2
  echo "  sudo chown -R \"$(id -un)\":\"$(id -gn)\" '$FLOX_ENV_DIR/.flox'" >&2
  exit 1
fi

if [[ ! -f "$FLOX_ENV_DIR/.flox/env.json" ]]; then
  env "${flox_env[@]}" "$FLOX_BIN" init -d "$FLOX_ENV_DIR" -n "$FLOX_ENV_NAME" --no-auto-setup
fi

env "${flox_env[@]}" "$FLOX_BIN" edit -d "$FLOX_ENV_DIR" -f "$FLOX_MANIFEST_PATH"

echo "Initialized and synced Flox environment at: $FLOX_ENV_DIR"