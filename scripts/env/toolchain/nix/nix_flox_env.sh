#!/usr/bin/env bash

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
fi

export NIX_ISOLATED_ROOT="${NIX_ISOLATED_ROOT:-/opt/bin/dev/nix}"
export NIX_MOUNT_POINT="${NIX_MOUNT_POINT:-/nix}"
export NIX_CONF_DIR="${NIX_CONF_DIR:-/etc/nix}"
export DETERMINATE_NIX_BIN="${DETERMINATE_NIX_BIN:-$NIX_MOUNT_POINT/var/nix/profiles/default/bin/nix}"
export DETERMINATE_NIX_INSTALLER_BIN="${DETERMINATE_NIX_INSTALLER_BIN:-$NIX_MOUNT_POINT/nix-installer}"
export NIX_DAEMON_PROFILE_SCRIPT="${NIX_DAEMON_PROFILE_SCRIPT:-$NIX_MOUNT_POINT/var/nix/profiles/default/etc/profile.d/nix-daemon.sh}"
export NIX_DAEMON_SOCKET="${NIX_DAEMON_SOCKET:-$NIX_MOUNT_POINT/var/nix/daemon-socket/socket}"
export NIX_WRAPPER_BIN="${NIX_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/nix}"
export NIX_INSTALLER_WRAPPER_BIN="${NIX_INSTALLER_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/nix-installer}"
export FLOX_WRAPPER_BIN="${FLOX_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/flox}"
export FLOX_PROFILE="${FLOX_PROFILE:-$NIX_MOUNT_POINT/var/nix/profiles/flox}"
export FLOX_ENV_DIR="${FLOX_ENV_DIR:-$PROJECT_ROOT/env/hybrid-ai}"
export FLOX_ENV_NAME="${FLOX_ENV_NAME:-${FLOX_ENV_DIR##*/}}"
export FLOX_MANIFEST_PATH="${FLOX_MANIFEST_PATH:-$FLOX_ENV_DIR/manifest.toml}"
export FLOX_DISABLE_METRICS="${FLOX_DISABLE_METRICS:-true}"

case "$NIX_ISOLATED_ROOT" in
  /nix|/nix/*)
    echo "ERROR: NIX_ISOLATED_ROOT must be a physical backing path, not under /nix: $NIX_ISOLATED_ROOT" >&2
    exit 1
    ;;
esac

if [[ ":$PATH:" != *":$NIX_ISOLATED_ROOT/bin:"* ]]; then
  export PATH="$NIX_ISOLATED_ROOT/bin:$PATH"
fi

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
  [[ "$(nix_mount_root)" == "$NIX_ISOLATED_ROOT" ]]
}

ensure_nix_bind_mount() {
  if ! is_nix_mount_active; then
    echo "ERROR: $NIX_MOUNT_POINT is not mounted." >&2
    return 1
  fi
}

source_nix_daemon_profile() {
  if [[ ! -r "$NIX_DAEMON_PROFILE_SCRIPT" ]]; then
    echo "ERROR: Nix daemon profile script not found at $NIX_DAEMON_PROFILE_SCRIPT" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  source "$NIX_DAEMON_PROFILE_SCRIPT"
}

use_nix_daemon() {
  source_nix_daemon_profile
  export NIX_REMOTE="${NIX_REMOTE:-daemon}"
}

require_nix_daemon_socket() {
  if [[ -S "$NIX_DAEMON_SOCKET" ]]; then
    return 0
  fi

  echo "ERROR: expected nix-daemon socket at $NIX_DAEMON_SOCKET" >&2
  echo "Start /nix/var/nix/profiles/default/bin/nix-daemon as root before using non-root Nix or Flox." >&2
  return 1
}

resolve_flox_bin() {
  if have_command flox; then
    command -v flox
    return 0
  fi

  if [[ -x "$FLOX_WRAPPER_BIN" ]]; then
    printf '%s\n' "$FLOX_WRAPPER_BIN"
    return 0
  fi

  return 1
}

require_flox_bin() {
  local flox_bin=""

  flox_bin="$(resolve_flox_bin || true)"
  if [[ -n "$flox_bin" ]]; then
    printf '%s\n' "$flox_bin"
    return 0
  fi

  echo "ERROR: flox is required but not installed or not in PATH." >&2
  return 1
}

hybrid_ai_require_flox_env() {
  local env_dir="${1:-$FLOX_ENV_DIR}"
  local manifest_path="$env_dir/manifest.toml"

  if [[ -f "$manifest_path" ]]; then
    return 0
  fi

  echo "ERROR: expected Flox manifest at $manifest_path" >&2
  return 1
}

hybrid_ai_flox_tool_env() {
  env \
    "XDG_CONFIG_HOME=$XDG_CONFIG_HOME" \
    "XDG_CACHE_HOME=$XDG_CACHE_HOME" \
    "XDG_DATA_HOME=$XDG_DATA_HOME" \
    "HOME=$HOME" \
    "FLOX_DISABLE_METRICS=$FLOX_DISABLE_METRICS" \
    "$@"
}

hybrid_ai_ensure_flox_env_ready() {
  local env_dir="${1:-$FLOX_ENV_DIR}"
  local init_script="${2:-$PROJECT_ROOT/scripts/env/toolchain/nix/flox_env_init.sh}"
  local flox_bin=""
  local activate_output=""
  local status=0

  hybrid_ai_require_flox_env "$env_dir" || return
  flox_bin="$(require_flox_bin)" || return

  set +e
  activate_output="$(hybrid_ai_flox_tool_env "$flox_bin" activate -d "$env_dir" -- bash --noprofile --norc -lc 'exit 0' 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    return 0
  fi

  if [[ "$activate_output" == *"manifest and lockfile are out of sync"* ]]; then
    if [[ ! -x "$init_script" ]]; then
      echo "ERROR: Flox environment state is stale, and sync helper is not executable: $init_script" >&2
      printf '%s\n' "$activate_output" >&2
      return "$status"
    fi

    echo "INFO: Flox environment state is stale; syncing manifests." >&2
    FLOX_ENV_DIR="$env_dir" "$init_script" >/dev/null
    return 0
  fi

  printf '%s\n' "$activate_output" >&2
  return "$status"
}
