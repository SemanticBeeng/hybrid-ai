#!/usr/bin/env bash
# Infrastructure setup and validation functions for Nix/Flox.
# Used by setup scripts (nix_mount_manage.sh, nix_determinate_install.sh, etc.)
# and doctor.sh for one-time validation.
#
# Assumes local_env.sh was sourced at shell startup.
#
# Project scripts (flox_with.sh, start_vscode.sh) should NOT source this file;
# use nix_flox_env.sh instead for flox activation.

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/shell_helpers.sh"

# Infrastructure paths (used by setup and validation scripts only).
: "${NIX_MOUNT_POINT:=/nix}"
: "${NIX_CONF_DIR:=/etc/nix}"
export DETERMINATE_NIX_BIN="${DETERMINATE_NIX_BIN:-$NIX_MOUNT_POINT/var/nix/profiles/default/bin/nix}"
export DETERMINATE_NIX_INSTALLER_BIN="${DETERMINATE_NIX_INSTALLER_BIN:-$NIX_MOUNT_POINT/nix-installer}"
export NIX_DAEMON_PROFILE_SCRIPT="${NIX_DAEMON_PROFILE_SCRIPT:-$NIX_MOUNT_POINT/var/nix/profiles/default/etc/profile.d/nix-daemon.sh}"
export NIX_DAEMON_SOCKET="${NIX_DAEMON_SOCKET:-$NIX_MOUNT_POINT/var/nix/daemon-socket/socket}"
export NIX_WRAPPER_BIN="${NIX_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/nix}"
export NIX_INSTALLER_WRAPPER_BIN="${NIX_INSTALLER_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/nix-installer}"
export FLOX_WRAPPER_BIN="${FLOX_WRAPPER_BIN:-$NIX_ISOLATED_ROOT/bin/flox}"
export FLOX_PROFILE="${FLOX_PROFILE:-$NIX_MOUNT_POINT/var/nix/profiles/flox}"
export NIX_ISOLATED_ROOT NIX_MOUNT_POINT NIX_CONF_DIR

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
  : "${NIX_REMOTE:=daemon}"
  export NIX_REMOTE
}

require_nix_daemon_socket() {
  if [[ -S "$NIX_DAEMON_SOCKET" ]]; then
    return 0
  fi

  echo "ERROR: expected nix-daemon socket at $NIX_DAEMON_SOCKET" >&2
  echo "Project scripts do not start host Nix services automatically." >&2
  echo "Start the daemon manually if needed, then rerun:" >&2
  echo "  sudo /nix/var/nix/profiles/default/bin/nix-daemon" >&2
  return 1
}
