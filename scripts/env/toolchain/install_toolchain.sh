#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

cat <<EOF
INFO: scripts/env/toolchain/install_toolchain.sh is a convenience/resume helper.
INFO: On a fresh machine, prefer the explicit step-by-step sequence from docs/chat/determinate_nix_flox_setup.md.
EOF

"$PROJECT_ROOT/scripts/env/toolchain/bootstrap_host.sh"
"$PROJECT_ROOT/scripts/env/toolchain/install_nix_determinate.sh"
"$PROJECT_ROOT/scripts/env/toolchain/install_flox.sh"

if [[ ! -S "$NIX_DAEMON_SOCKET" ]]; then
	cat <<EOF >&2
ERROR: expected nix-daemon socket at $NIX_DAEMON_SOCKET
Start /nix/var/nix/profiles/default/bin/nix-daemon as root, then rerun scripts/env/toolchain/install_toolchain.sh or scripts/env/toolchain/init_flox_env.sh.
EOF
	exit 1
fi

"$PROJECT_ROOT/scripts/env/toolchain/init_flox_env.sh"
"$PROJECT_ROOT/scripts/env/toolchain/check_nix_isolation.sh"
"$PROJECT_ROOT/scripts/env/toolchain/doctor.sh"

cat <<EOF
Toolchain installation completed.
Role: convenience/resume helper for an already-understood bootstrap flow.
Installed binaries:
1) $NIX_WRAPPER_BIN
2) $FLOX_WRAPPER_BIN
Next:
1) scripts/env/with_flox.sh python --version
2) scripts/env/with_flox.sh swift --version
3) scripts/env/run_inference_local.sh "healthcheck"
EOF
