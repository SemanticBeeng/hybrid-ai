#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

"$PROJECT_ROOT/scripts/env/bootstrap_host.sh"
"$PROJECT_ROOT/scripts/env/install_nix_determinate.sh"
"$PROJECT_ROOT/scripts/env/install_flox.sh"
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
