#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

mkdir -p "$PROJECT_ROOT/build" "$PROJECT_ROOT/volumes" "$PROJECT_ROOT/deps"

"$PROJECT_ROOT/scripts/env/manage_nix_mount.sh" prepare
"$PROJECT_ROOT/scripts/env/manage_nix_mount.sh" mount

run_as_root mkdir -p "$NIX_CONF_DIR"

if [[ ! -f "$NIX_CONF_DIR/nix.conf" ]]; then
  echo "INFO: $NIX_CONF_DIR/nix.conf does not exist yet; Determinate installer will create it." >&2
fi

cat <<EOF
Bootstrap complete.
Mountpoint: $NIX_MOUNT_POINT
Backing root: $NIX_ISOLATED_ROOT
Nix config dir: $NIX_CONF_DIR
Next: run scripts/env/install_toolchain.sh, then scripts/verify/check_nix_isolation.sh
EOF
