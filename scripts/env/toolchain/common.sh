#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

# Compatibility aggregator. Prefer sourcing the narrower concern files directly
# when a script only needs one subsystem.
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/project_paths.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/xdg_env.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/nix/nix_flox_env.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/swift/swift_paths.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/inference_env.sh"
