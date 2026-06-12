#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/common.sh"
source "$project_root/scripts/env/toolchain/nix/nix_setup.sh"

mkdir -p "$project_root/build" "$project_root/volumes" "$project_root/deps"

"$project_root/scripts/env/toolchain/nix/nix_mount_manage.sh" prepare
"$project_root/scripts/env/toolchain/nix/nix_mount_manage.sh" mount

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
2) scripts/env/toolchain/nix/nix_determinate_install.sh
3) scripts/env/toolchain/nix/flox_install.sh
4) if $NIX_DAEMON_SOCKET is absent, start the daemon manually:
  sudo /nix/var/nix/profiles/default/bin/nix-daemon
5) scripts/env/toolchain/nix/flox_env_init.sh
Optional shortcut after you understand the flow:
- scripts/env/toolchain/nix/toolchain_install.sh
EOF
