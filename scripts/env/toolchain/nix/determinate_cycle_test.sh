#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$project_root/scripts/env/toolchain/common.sh"

DETERMINATE_INSTALLER_URL="${DETERMINATE_INSTALLER_URL:-https://install.determinate.systems/nix}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--download-installer]

Purpose:
  Perform a non-destructive validation of the uninstall/reinstall path for the
  bind-mounted Determinate Nix setup.

Behavior:
  - verifies the configured /nix bind mount backing root
  - prints current wrapper and receipt status
  - runs 'nix-installer uninstall --explain' when an installed installer exists
  - optionally downloads the current installer and runs 'install ... --explain'
    only when no live install is present; otherwise it prints the exact command
    that would be used after uninstall.

Options:
  --download-installer   Download the current installer and prepare an install dry-run.
EOF
}

download_installer=false
case "${1:-}" in
  "")
    ;;
  --download-installer)
    download_installer=true
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

installer_bin=""
if [[ -x "$DETERMINATE_NIX_INSTALLER_BIN" ]]; then
  installer_bin="$DETERMINATE_NIX_INSTALLER_BIN"
elif [[ -x "$NIX_INSTALLER_WRAPPER_BIN" ]]; then
  installer_bin="$NIX_INSTALLER_WRAPPER_BIN"
fi

"$project_root/scripts/env/toolchain/nix/nix_mount_manage.sh" status
ensure_nix_bind_mount

echo "NIX_MOUNT_POINT=$NIX_MOUNT_POINT"
echo "NIX_ISOLATED_ROOT=$NIX_ISOLATED_ROOT"
echo "NIX_WRAPPER_BIN=$NIX_WRAPPER_BIN"
echo "FLOX_WRAPPER_BIN=$FLOX_WRAPPER_BIN"
echo "DETERMINATE_NIX_INSTALLER_BIN=${installer_bin:-missing}"

if [[ -x "$NIX_WRAPPER_BIN" ]]; then
  echo "Current nix version:"
  run_as_root "$NIX_WRAPPER_BIN" --version
else
  echo "WARN: nix wrapper missing at $NIX_WRAPPER_BIN" >&2
fi

if [[ -x "$FLOX_WRAPPER_BIN" ]]; then
  echo "Current flox version:"
  run_as_root "$FLOX_WRAPPER_BIN" --version
else
  echo "WARN: flox wrapper missing at $FLOX_WRAPPER_BIN" >&2
fi

if [[ -f "$NIX_MOUNT_POINT/receipt.json" ]]; then
  echo "Receipt present: $NIX_MOUNT_POINT/receipt.json"
else
  echo "WARN: receipt missing at $NIX_MOUNT_POINT/receipt.json" >&2
fi

if [[ -n "$installer_bin" ]]; then
  echo "Uninstall dry-run via installed Determinate installer:"
  run_as_root "$installer_bin" uninstall --explain
else
  echo "WARN: installed Determinate installer not found; uninstall dry-run skipped." >&2
fi

reinstall_command="sh <downloaded-installer> install linux --no-confirm --no-modify-profile --diagnostic-endpoint= --no-start-daemon --explain"

if [[ "$download_installer" == true ]]; then
  if [[ -n "$installer_bin" || -f "$NIX_MOUNT_POINT/receipt.json" ]]; then
    echo "Install dry-run skipped because a live Determinate install is still present."
    echo "Run this after uninstall if you want the installer preflight itself exercised non-destructively:"
    echo "$reinstall_command"
  else
    tmp_file="$(mktemp)"
    trap 'rm -f "$tmp_file"' EXIT
    echo "Downloading installer for install dry-run from: $DETERMINATE_INSTALLER_URL"
    curl --proto '=https' --tlsv1.2 -fsSL "$DETERMINATE_INSTALLER_URL" -o "$tmp_file"
    echo "Install dry-run via downloaded installer:"
    run_as_root sh "$tmp_file" install linux --no-confirm --no-modify-profile --diagnostic-endpoint= --no-start-daemon --explain
  fi
else
  echo "Install dry-run skipped. Re-run with --download-installer to prepare an install preflight check."
fi

echo "Non-destructive Determinate cycle check complete."