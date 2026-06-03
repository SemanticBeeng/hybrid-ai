#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

"$PROJECT_ROOT/scripts/env/install_nix_determinate.sh"
"$PROJECT_ROOT/scripts/env/install_flox.sh"

cat <<EOF
Toolchain installation completed.
Installed binaries:
1) $NIX_ISOLATED_ROOT/bin/nix
2) $NIX_ISOLATED_ROOT/bin/flox
Next:
1) scripts/env/bootstrap_host.sh
2) scripts/verify/check_nix_isolation.sh
3) scripts/verify/doctor.sh
EOF
