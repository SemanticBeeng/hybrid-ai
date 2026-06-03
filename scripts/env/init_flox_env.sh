#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

FLOX_ENV_DIR="${FLOX_ENV_DIR:-$PROJECT_ROOT/env/hybrid-ai}"
FLOX_ENV_NAME="${FLOX_ENV_NAME:-$(basename "$FLOX_ENV_DIR")}"
FLOX_MANIFEST_PATH="${FLOX_MANIFEST_PATH:-$FLOX_ENV_DIR/manifest.toml}"
FLOX_DISABLE_METRICS=true

if [[ ! -x "$FLOX_WRAPPER_BIN" ]]; then
  echo "ERROR: flox wrapper not found at $FLOX_WRAPPER_BIN" >&2
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
  if [[ -e "$flox_dir" || -L "$flox_dir" ]]; then
    run_as_root chown -R "$(id -un):$(id -gn)" "$flox_dir"
  fi
done

if [[ ! -f "$FLOX_ENV_DIR/.flox/env.json" ]]; then
  env "${flox_env[@]}" "$FLOX_WRAPPER_BIN" init -d "$FLOX_ENV_DIR" -n "$FLOX_ENV_NAME" --no-auto-setup
fi

run_as_root env "${flox_env[@]}" "$FLOX_WRAPPER_BIN" edit -d "$FLOX_ENV_DIR" -f "$FLOX_MANIFEST_PATH"

echo "Initialized and synced Flox environment at: $FLOX_ENV_DIR"