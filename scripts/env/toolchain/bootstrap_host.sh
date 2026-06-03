#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

mkdir -p "$PROJECT_ROOT/build" "$PROJECT_ROOT/volumes" "$PROJECT_ROOT/deps"

"$PROJECT_ROOT/scripts/env/toolchain/manage_nix_mount.sh" prepare
"$PROJECT_ROOT/scripts/env/toolchain/manage_nix_mount.sh" mount

run_as_root mkdir -p "$NIX_CONF_DIR"

if [[ ! -f "$NIX_CONF_DIR/nix.conf" ]]; then
  echo "INFO: $NIX_CONF_DIR/nix.conf does not exist yet; Determinate installer will create it." >&2
fi

cat <<EOF
Bootstrap complete.
Mountpoint: $NIX_MOUNT_POINT
Backing root: $NIX_ISOLATED_ROOT
Nix config dir: $NIX_CONF_DIR
Next (fresh machine):
1) sudo -v
2) scripts/env/toolchain/install_nix_determinate.sh
3) scripts/env/toolchain/install_flox.sh
4) sudo /nix/var/nix/profiles/default/bin/nix-daemon
5) scripts/env/toolchain/init_flox_env.sh
Optional shortcut after you understand the flow:
- scripts/env/toolchain/install_toolchain.sh
EOF
