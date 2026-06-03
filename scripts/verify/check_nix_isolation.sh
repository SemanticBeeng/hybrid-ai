#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

if [[ "$NIX_ISOLATED_ROOT" != "/opt/bin/dev/nix" ]]; then
  echo "WARN: NIX_ISOLATED_ROOT is '$NIX_ISOLATED_ROOT', expected '/opt/bin/dev/nix'." >&2
fi

case "$NIX_ISOLATED_ROOT" in
  /nix|/nix/*)
    echo "ERROR: NIX_ISOLATED_ROOT points to root /nix path: $NIX_ISOLATED_ROOT" >&2
    exit 1
    ;;
esac

if [[ ! -d "$NIX_ISOLATED_ROOT" ]]; then
  echo "WARN: NIX_ISOLATED_ROOT does not exist on this host yet: $NIX_ISOLATED_ROOT" >&2
fi

if [[ -d "/nix" ]]; then
  echo "ERROR: detected root /nix directory. This project forbids root-based nix installs." >&2
  echo "Run scripts/env/remove_root_nix.sh with CONFIRM_REMOVE_ROOT_NIX=YES to remove it." >&2
  exit 1
fi

echo "OK: root /nix directory not present."

echo "Nix isolation check complete."
