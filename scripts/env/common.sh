#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export NIX_ISOLATED_ROOT="${NIX_ISOLATED_ROOT:-/opt/bin/dev/nix}"
export NIX_MOUNT_POINT="${NIX_MOUNT_POINT:-/nix}"
export NIX_CONF_DIR="${NIX_CONF_DIR:-/etc/nix}"
export DETERMINATE_NIX_BIN="${DETERMINATE_NIX_BIN:-$NIX_MOUNT_POINT/var/nix/profiles/default/bin/nix}"
export DETERMINATE_NIX_INSTALLER_BIN="${DETERMINATE_NIX_INSTALLER_BIN:-$NIX_MOUNT_POINT/nix-installer}"
export NIX_WRAPPER_BIN="${NIX_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/nix}"
export NIX_INSTALLER_WRAPPER_BIN="${NIX_INSTALLER_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/nix-installer}"
export FLOX_WRAPPER_BIN="${FLOX_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/flox}"
export FLOX_PROFILE="${FLOX_PROFILE:-$NIX_MOUNT_POINT/var/nix/profiles/flox}"
export PATH="$NIX_ISOLATED_ROOT/bin:$PATH"

case "$NIX_ISOLATED_ROOT" in
  /nix|/nix/*)
    echo "ERROR: NIX_ISOLATED_ROOT must be a physical backing path, not under /nix: $NIX_ISOLATED_ROOT" >&2
    exit 1
    ;;
esac

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

have_command() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi

  if have_command sudo; then
    sudo -n "$@"
    return
  fi

  echo "ERROR: root privileges are required for: $*" >&2
  return 1
}

nix_mount_source() {
  if have_command findmnt; then
    findmnt -n -o SOURCE --target "$NIX_MOUNT_POINT" 2>/dev/null || true
    return
  fi

  awk -v target="$NIX_MOUNT_POINT" '$5 == target { print $10 }' /proc/self/mountinfo | tail -n 1
}

nix_mount_root() {
  local source
  source="$(nix_mount_source)"

  if [[ "$source" == *'['*']'* ]]; then
    source="${source#*[}"
    source="${source%]}"
  fi

  printf '%s\n' "$source"
}

is_nix_mount_active() {
  if have_command mountpoint; then
    mountpoint -q "$NIX_MOUNT_POINT"
    return
  fi

  [[ -n "$(nix_mount_root)" ]]
}

is_nix_bind_mounted_to_isolated_root() {
  local mount_stat root_stat

  if [[ ! -e "$NIX_MOUNT_POINT" || ! -e "$NIX_ISOLATED_ROOT" ]]; then
    return 1
  fi

  mount_stat="$(stat -Lc '%d:%i' "$NIX_MOUNT_POINT" 2>/dev/null || true)"
  root_stat="$(stat -Lc '%d:%i' "$NIX_ISOLATED_ROOT" 2>/dev/null || true)"

  [[ -n "$mount_stat" && "$mount_stat" == "$root_stat" ]]
}

ensure_nix_bind_mount() {
  if ! is_nix_mount_active; then
    echo "ERROR: $NIX_MOUNT_POINT is not mounted." >&2
    return 1
  fi

  if ! is_nix_bind_mounted_to_isolated_root; then
    echo "ERROR: $NIX_MOUNT_POINT is mounted, but not from $NIX_ISOLATED_ROOT." >&2
    echo "Detected mount root: $(nix_mount_root)" >&2
    return 1
  fi
}
