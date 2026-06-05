#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Compatibility aggregator. Prefer sourcing the narrower concern files directly
# when a script only needs one subsystem.
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/project_paths.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/nix/nix_flox_env.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/xdg_env.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/python/python_paths.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/swift/swift_paths.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/inference_env.sh"
