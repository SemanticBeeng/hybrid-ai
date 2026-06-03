#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export NIX_ISOLATED_ROOT="${NIX_ISOLATED_ROOT:-/opt/bin/dev/nix}"
export NIX_CONF_DIR="${NIX_CONF_DIR:-$NIX_ISOLATED_ROOT/etc/nix}"

export XDG_CONFIG_HOME="$PROJECT_ROOT/build/xdg/config"
export XDG_CACHE_HOME="$PROJECT_ROOT/build/xdg/cache"
export XDG_DATA_HOME="$PROJECT_ROOT/build/xdg/data"
export XDG_STATE_HOME="$PROJECT_ROOT/build/xdg/state"

# Use an isolated HOME for tools that hardcode HOME lookups.
export HOME="$PROJECT_ROOT/build/home"

export PYTHON_DIR="$PROJECT_ROOT/src/python"
export VIRTUAL_ENV="$PROJECT_ROOT/build/python/venv"
export PIP_CACHE_DIR="$PROJECT_ROOT/build/python/cache/pip"
export POETRY_CACHE_DIR="$PROJECT_ROOT/build/python/cache/poetry"
export UV_CACHE_DIR="$PROJECT_ROOT/build/python/cache/uv"
export PYTHONPYCACHEPREFIX="$PROJECT_ROOT/build/python/pycache"
export PYTHONDONTWRITEBYTECODE=1
export PIP_DISABLE_PIP_VERSION_CHECK=1

export SWIFT_BUILD_PATH="$PROJECT_ROOT/build/swift"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/build/swift/clang-module-cache"
export SWIFTPM_PACKAGECACHE="$PROJECT_ROOT/build/swift/package-cache"

export CACTUS_MODEL_PATH="$PROJECT_ROOT/volumes/models/cactus"
export LITERT_LM_MODELS="$PROJECT_ROOT/volumes/models/litert-lm"
export HF_HOME="$PROJECT_ROOT/volumes/cache/huggingface"
export TRANSFORMERS_CACHE="$PROJECT_ROOT/volumes/cache/transformers"

mkdir -p \
  "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
  "$HOME" "$PIP_CACHE_DIR" "$POETRY_CACHE_DIR" "$UV_CACHE_DIR" "$PYTHONPYCACHEPREFIX" \
  "$SWIFT_BUILD_PATH" "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_PACKAGECACHE" \
  "$CACTUS_MODEL_PATH" "$LITERT_LM_MODELS" "$HF_HOME" "$TRANSFORMERS_CACHE" \
  "$PROJECT_ROOT/volumes/logs" "$PROJECT_ROOT/build/artifacts" "$PROJECT_ROOT/deps/libs" "$PROJECT_ROOT/deps/models"

assert_under_project() {
  local p="$1"
  case "$p" in
    "$PROJECT_ROOT"/*) ;;
    *)
      echo "ERROR: path outside project root: $p" >&2
      return 1
      ;;
  esac
}

assert_under_project "$XDG_CONFIG_HOME"
assert_under_project "$XDG_CACHE_HOME"
assert_under_project "$XDG_DATA_HOME"
assert_under_project "$XDG_STATE_HOME"
assert_under_project "$HOME"
assert_under_project "$PIP_CACHE_DIR"
assert_under_project "$POETRY_CACHE_DIR"
assert_under_project "$UV_CACHE_DIR"
assert_under_project "$PYTHONPYCACHEPREFIX"
assert_under_project "$SWIFT_BUILD_PATH"
assert_under_project "$CACTUS_MODEL_PATH"
assert_under_project "$LITERT_LM_MODELS"
