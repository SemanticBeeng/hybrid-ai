#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

FLOX_BIN=""
if command -v flox >/dev/null 2>&1; then
  FLOX_BIN="$(command -v flox)"
elif [[ -x "$FLOX_WRAPPER_BIN" ]]; then
  FLOX_BIN="$FLOX_WRAPPER_BIN"
fi

if [[ -z "$FLOX_BIN" ]]; then
  echo "ERROR: flox is required but not installed or not in PATH." >&2
  exit 1
fi

FLOX_ENV_DIR="$PROJECT_ROOT/env/hybrid-ai"
if [[ ! -f "$FLOX_ENV_DIR/manifest.toml" ]]; then
  echo "ERROR: expected Flox manifest at $FLOX_ENV_DIR/manifest.toml" >&2
  exit 1
fi

pass_env=(
  "PROJECT_ROOT=$PROJECT_ROOT"
  "NIX_ISOLATED_ROOT=$NIX_ISOLATED_ROOT"
  "NIX_MOUNT_POINT=$NIX_MOUNT_POINT"
  "NIX_CONF_DIR=$NIX_CONF_DIR"
  "HOME=$HOME"
  "PATH=$PATH"
  "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
  "XDG_CACHE_HOME=$XDG_CACHE_HOME"
  "XDG_DATA_HOME=$XDG_DATA_HOME"
  "XDG_STATE_HOME=$XDG_STATE_HOME"
  "PYTHON_DIR=$PYTHON_DIR"
  "VIRTUAL_ENV=$VIRTUAL_ENV"
  "PIP_CACHE_DIR=$PIP_CACHE_DIR"
  "POETRY_CACHE_DIR=$POETRY_CACHE_DIR"
  "UV_CACHE_DIR=$UV_CACHE_DIR"
  "PYTHONPYCACHEPREFIX=$PYTHONPYCACHEPREFIX"
  "SWIFT_BUILD_PATH=$SWIFT_BUILD_PATH"
  "CLANG_MODULE_CACHE_PATH=$CLANG_MODULE_CACHE_PATH"
  "SWIFTPM_PACKAGECACHE=$SWIFTPM_PACKAGECACHE"
  "CACTUS_MODEL_PATH=$CACTUS_MODEL_PATH"
  "LITERT_LM_MODELS=$LITERT_LM_MODELS"
  "HF_HOME=$HF_HOME"
  "TRANSFORMERS_CACHE=$TRANSFORMERS_CACHE"
)

flox_cmd=("$FLOX_BIN" activate -d "$FLOX_ENV_DIR" --)
if [[ $# -eq 0 ]]; then
  flox_cmd+=(bash --noprofile --norc)
else
  flox_cmd+=("$@")
fi

if [[ "$(id -u)" -eq 0 ]]; then
  exec "${flox_cmd[@]}"
fi

if ! have_command sudo; then
  echo "ERROR: root-oriented Flox activation requires sudo on this host." >&2
  exit 1
fi

exec sudo env "${pass_env[@]}" "${flox_cmd[@]}"
