#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

cat <<EOF
INFO: scripts/env/toolchain/nix/toolchain_install.sh is a convenience/resume helper.
INFO: On a fresh machine, prefer the explicit step-by-step sequence from docs/chat/determinate_nix_flox_setup.md.
EOF

"$PROJECT_ROOT/scripts/env/toolchain/nix/host_bootstrap.sh"
"$PROJECT_ROOT/scripts/env/toolchain/nix/nix_determinate_install.sh"
"$PROJECT_ROOT/scripts/env/toolchain/nix/flox_install.sh"

if [[ ! -S "$NIX_DAEMON_SOCKET" ]]; then
	cat <<EOF >&2
ERROR: expected nix-daemon socket at $NIX_DAEMON_SOCKET
Project scripts do not start host Nix services automatically.
Start the daemon manually if needed, then rerun scripts/env/toolchain/nix/toolchain_install.sh or scripts/env/toolchain/nix/flox_env_init.sh:
  sudo /nix/var/nix/profiles/default/bin/nix-daemon
EOF
	exit 1
fi

"$PROJECT_ROOT/scripts/env/toolchain/nix/flox_env_init.sh"
"$PROJECT_ROOT/scripts/env/toolchain/nix/nix_isolation_check.sh"
"$PROJECT_ROOT/scripts/env/toolchain/doctor.sh"

cat <<EOF
Toolchain installation completed.
Role: convenience/resume helper for an already-understood bootstrap flow.
Installed binaries:
1) $NIX_WRAPPER_BIN
2) $FLOX_WRAPPER_BIN
Next:
1) scripts/env/toolchain/nix/flox_with.sh python --version
2) scripts/env/toolchain/nix/flox_with.sh swift --version
3) scripts/env/run_inference_local.sh "healthcheck"
EOF
