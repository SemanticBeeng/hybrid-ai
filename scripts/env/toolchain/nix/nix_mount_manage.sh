#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$project_root/scripts/env/toolchain/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <prepare|mount|status|unmount>

Commands:
  prepare   Create the physical backing tree and logical /nix mountpoint.
  mount     Bind-mount $NIX_ISOLATED_ROOT onto $NIX_MOUNT_POINT.
  status    Print the current mount status for $NIX_MOUNT_POINT.
  unmount   Unmount $NIX_MOUNT_POINT if it is bound to $NIX_ISOLATED_ROOT.
EOF
}

prepare_mount() {
  run_as_root mkdir -p \
    "$NIX_ISOLATED_ROOT/bin" \
    "$NIX_ISOLATED_ROOT/store" \
    "$NIX_ISOLATED_ROOT/tmp" \
    "$NIX_ISOLATED_ROOT/var/nix" \
    "$NIX_ISOLATED_ROOT/etc/nix"
  run_as_root chmod 0755 "$NIX_ISOLATED_ROOT" "$NIX_ISOLATED_ROOT/bin" "$NIX_ISOLATED_ROOT/store" "$NIX_ISOLATED_ROOT/tmp"

  if [[ -e "$NIX_MOUNT_POINT" && ! -d "$NIX_MOUNT_POINT" ]]; then
    echo "ERROR: $NIX_MOUNT_POINT exists but is not a directory." >&2
    exit 1
  fi

  run_as_root mkdir -p "$NIX_MOUNT_POINT"
}

mount_bind() {
  prepare_mount

  if is_nix_mount_active; then
    if is_nix_bind_mounted_to_isolated_root; then
      echo "OK: $NIX_MOUNT_POINT already bind-mounted from $NIX_ISOLATED_ROOT"
      return
    fi

    echo "ERROR: $NIX_MOUNT_POINT is already mounted from $(nix_mount_root), not $NIX_ISOLATED_ROOT." >&2
    exit 1
  fi

  run_as_root mount --bind "$NIX_ISOLATED_ROOT" "$NIX_MOUNT_POINT"
  ensure_nix_bind_mount
  echo "Mounted $NIX_MOUNT_POINT from $NIX_ISOLATED_ROOT"
}

status_mount() {
  if ! [[ -d "$NIX_MOUNT_POINT" ]]; then
    echo "status=missing mountpoint=$NIX_MOUNT_POINT"
    return
  fi

  if ! is_nix_mount_active; then
    echo "status=unmounted mountpoint=$NIX_MOUNT_POINT backing=$NIX_ISOLATED_ROOT"
    return
  fi

  if is_nix_bind_mounted_to_isolated_root; then
    echo "status=mounted mountpoint=$NIX_MOUNT_POINT backing=$NIX_ISOLATED_ROOT"
    return
  fi

  echo "status=mounted mountpoint=$NIX_MOUNT_POINT detected_root=$(nix_mount_root) expected_root=$NIX_ISOLATED_ROOT verification=root_mismatch"
}

unmount_bind() {
  if ! is_nix_mount_active; then
    echo "OK: $NIX_MOUNT_POINT is not mounted"
    return
  fi

  if ! is_nix_bind_mounted_to_isolated_root; then
    echo "ERROR: refusing to unmount unexpected $NIX_MOUNT_POINT mount from $(nix_mount_root)." >&2
    exit 1
  fi

  run_as_root umount "$NIX_MOUNT_POINT"
  echo "Unmounted $NIX_MOUNT_POINT"
}

case "${1:-}" in
  prepare)
    prepare_mount
    ;;
  mount)
    mount_bind
    ;;
  status)
    status_mount
    ;;
  unmount)
    unmount_bind
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac