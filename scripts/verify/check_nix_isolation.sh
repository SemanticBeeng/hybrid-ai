#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

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

if ! is_nix_bind_mounted_to_isolated_root; then
  echo "ERROR: $NIX_MOUNT_POINT is not bind-mounted from $NIX_ISOLATED_ROOT." >&2
  echo "Detected mount root: $(nix_mount_root)" >&2
  exit 1
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
  echo "Start /nix/var/nix/profiles/default/bin/nix-daemon as root before using normal-user Nix or Flox." >&2
  exit 1
fi

if [[ -e "$NIX_MOUNT_POINT" && ! is_nix_bind_mounted_to_isolated_root ]]; then
  echo "ERROR: $NIX_MOUNT_POINT exists outside the expected bind mount." >&2
  exit 1
fi

echo "Nix isolation check complete."
