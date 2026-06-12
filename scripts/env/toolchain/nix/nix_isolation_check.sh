#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/nix/nix_setup.sh"

if [[ "$NIX_ISOLATED_ROOT" != "/opt/bin/dev/nix" ]]; then
  echo "WARN: NIX_ISOLATED_ROOT is '$NIX_ISOLATED_ROOT', expected '/opt/bin/dev/nix'." >&2
fi

if [[ ! -d "$NIX_ISOLATED_ROOT" ]]; then
  echo "ERROR: NIX_ISOLATED_ROOT does not exist on this host: $NIX_ISOLATED_ROOT" >&2
  exit 1
fi

if [[ ! -d "$NIX_MOUNT_POINT" ]]; then
  echo "ERROR: expected mountpoint directory at $NIX_MOUNT_POINT" >&2
  exit 1
fi

if ! is_nix_mount_active; then
  echo "ERROR: $NIX_MOUNT_POINT exists but is not mounted." >&2
  exit 1
fi

detected_mount_root="$(nix_mount_root)"
if [[ -n "$detected_mount_root" && "$detected_mount_root" != "$NIX_ISOLATED_ROOT" ]]; then
  echo "WARN: mount verification=root_mismatch detected_root='$detected_mount_root' expected_root='$NIX_ISOLATED_ROOT'." >&2
  echo "WARN: current wrapper policy only requires that $NIX_MOUNT_POINT is mounted and usable." >&2
fi

if [[ -d "$NIX_MOUNT_POINT/store" ]]; then
  echo "OK: logical store present at $NIX_MOUNT_POINT/store"
else
  echo "WARN: logical store not present yet at $NIX_MOUNT_POINT/store" >&2
fi

if [[ -x "$NIX_WRAPPER_BIN" ]]; then
  echo "OK: nix wrapper present at $NIX_WRAPPER_BIN"
else
  echo "WARN: nix wrapper missing at $NIX_WRAPPER_BIN" >&2
fi

if [[ -x "$FLOX_WRAPPER_BIN" ]]; then
  echo "OK: flox wrapper present at $FLOX_WRAPPER_BIN"
else
  echo "WARN: flox wrapper missing at $FLOX_WRAPPER_BIN" >&2
fi

if [[ -x "$DETERMINATE_NIX_INSTALLER_BIN" ]]; then
  echo "OK: Determinate installer present at $DETERMINATE_NIX_INSTALLER_BIN"
else
  echo "WARN: Determinate installer missing at $DETERMINATE_NIX_INSTALLER_BIN" >&2
fi

if [[ -f "$NIX_MOUNT_POINT/receipt.json" ]]; then
  echo "OK: Determinate receipt present at $NIX_MOUNT_POINT/receipt.json"
else
  echo "WARN: Determinate receipt missing at $NIX_MOUNT_POINT/receipt.json" >&2
fi

if [[ -r "$NIX_DAEMON_PROFILE_SCRIPT" ]]; then
  echo "OK: nix-daemon profile script present at $NIX_DAEMON_PROFILE_SCRIPT"
else
  echo "ERROR: nix-daemon profile script missing or unreadable at $NIX_DAEMON_PROFILE_SCRIPT" >&2
  exit 1
fi

if [[ -S "$NIX_DAEMON_SOCKET" ]]; then
  echo "OK: nix-daemon socket present at $NIX_DAEMON_SOCKET"
else
  echo "ERROR: nix-daemon socket missing at $NIX_DAEMON_SOCKET" >&2
  echo "Project scripts do not start host Nix services automatically." >&2
  echo "Start the daemon manually if needed, then rerun:" >&2
  echo "  sudo /nix/var/nix/profiles/default/bin/nix-daemon" >&2
  exit 1
fi

echo "Nix isolation check complete."
