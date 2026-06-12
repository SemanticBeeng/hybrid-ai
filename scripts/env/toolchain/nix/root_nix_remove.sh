#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/common.sh"
source "$project_root/scripts/env/toolchain/nix/nix_setup.sh"

if [[ "${CONFIRM_REMOVE_ROOT_NIX:-}" != "YES" ]]; then
  echo "Refusing removal without explicit confirmation." >&2
  echo "Re-run with: CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/toolchain/nix/root_nix_remove.sh" >&2
  exit 1
fi

if is_nix_mount_active && is_nix_bind_mounted_to_isolated_root; then
  echo "ERROR: $NIX_MOUNT_POINT is the configured bind mount for $NIX_ISOLATED_ROOT." >&2
  echo "Use scripts/env/toolchain/nix/nix_mount_manage.sh unmount if you intend to dismantle the bind-mounted workflow." >&2
  exit 1
fi

if is_nix_mount_active; then
  echo "Unmounting legacy $NIX_MOUNT_POINT mount from $(nix_mount_root)"
  run_as_root umount "$NIX_MOUNT_POINT"
fi

remove_path() {
  local p="$1"
  if [[ -e "$p" || -L "$p" ]]; then
    run_as_root rm -rf "$p"
    echo "Removed: $p"
  fi
}

if [[ ! -e "$NIX_MOUNT_POINT" && ! -e "/etc/nix" && ! -e "/etc/profile.d/nix.sh" ]]; then
  echo "No incompatible root-backed Nix installation found."
  exit 0
fi

remove_path "$NIX_MOUNT_POINT"
remove_path "/etc/nix"
remove_path "/etc/profile.d/nix.sh"
remove_path "/etc/bashrc.backup-before-nix"
remove_path "/etc/zshrc.backup-before-nix"

echo "Root nix cleanup complete."
echo "Next: run scripts/env/toolchain/nix/host_bootstrap.sh and scripts/env/toolchain/nix/nix_isolation_check.sh"
