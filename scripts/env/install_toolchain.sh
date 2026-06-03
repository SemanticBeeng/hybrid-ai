#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

"$PROJECT_ROOT/scripts/env/bootstrap_host.sh"
"$PROJECT_ROOT/scripts/env/install_nix_determinate.sh"
"$PROJECT_ROOT/scripts/env/install_flox.sh"

if [[ ! -S "$NIX_DAEMON_SOCKET" ]]; then
	cat <<EOF >&2
ERROR: expected nix-daemon socket at $NIX_DAEMON_SOCKET
Start /nix/var/nix/profiles/default/bin/nix-daemon as root, then rerun scripts/env/install_toolchain.sh or scripts/env/init_flox_env.sh.
EOF
	exit 1
fi

"$PROJECT_ROOT/scripts/env/init_flox_env.sh"
"$PROJECT_ROOT/scripts/verify/check_nix_isolation.sh"
"$PROJECT_ROOT/scripts/verify/doctor.sh"

cat <<EOF
Toolchain installation completed.
Installed binaries:
1) $NIX_WRAPPER_BIN
2) $FLOX_WRAPPER_BIN
Next:
1) scripts/env/with_flox.sh python --version
2) scripts/env/with_flox.sh swift --version
3) scripts/env/run_inference_local.sh "healthcheck"
EOF
