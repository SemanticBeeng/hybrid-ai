#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ "${CONFIRM_REMOVE_ROOT_NIX:-}" != "YES" ]]; then
  echo "Refusing removal without explicit confirmation." >&2
  echo "Re-run with: CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/remove_root_nix.sh" >&2
  exit 1
fi

if [[ ! -d "/nix" ]]; then
  echo "No root /nix directory found. Nothing to remove."
  exit 0
fi

remove_path() {
  local p="$1"
  if [[ -e "$p" || -L "$p" ]]; then
    if [[ -w "$p" ]] || [[ -w "$(dirname "$p")" ]]; then
      rm -rf "$p"
    elif command -v sudo >/dev/null 2>&1; then
      sudo rm -rf "$p"
    else
      echo "ERROR: cannot remove $p without permissions or sudo." >&2
      return 1
    fi
    echo "Removed: $p"
  fi
}

remove_path "/nix"
remove_path "/etc/nix"
remove_path "/etc/profile.d/nix.sh"
remove_path "/etc/bashrc.backup-before-nix"
remove_path "/etc/zshrc.backup-before-nix"

echo "Root nix cleanup complete."
echo "Next: run scripts/env/bootstrap_host.sh and scripts/verify/check_nix_isolation.sh"
