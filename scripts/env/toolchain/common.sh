#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Compatibility aggregator. Prefer sourcing the narrower concern files directly
# when a script only needs one subsystem.
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/project_paths.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/xdg_env.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/nix/nix_flox_env.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/swift/swift_paths.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/inference_env.sh"
