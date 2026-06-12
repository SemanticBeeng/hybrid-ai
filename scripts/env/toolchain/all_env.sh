#!/usr/bin/env bash
# all_env.sh — Comprehensive environment aggregator for ad-hoc interactive shells.
#
# PURPOSE:
#   Sources ALL concern modules at once for broad external-shell setup.
#   Use this when you need the complete project environment in an interactive shell.
#
# NOT USED BY:
#   - Flox manifest activation hooks (manifests source narrow modules directly)
#   - Wrapper scripts like flox_with.sh, start_vscode.sh, swiftly_install.sh
#   - Any script in the Flox activation control flow
#
# USED BY:
#   - check_env.sh (comprehensive environment diagnostic)
#   - project_cache_cleanup.sh (recreates cache directories after cleanup)
#   - Ad-hoc interactive shells: source scripts/env/toolchain/all_env.sh
#
# PREFER:
#   For narrow concerns, source the specific module directly:
#   - nix_flox_env.sh for Flox activation defaults
#   - xdg_env.sh for XDG/HOME isolation
#   - swift_env.sh for Swift/Swiftly activation
#   - inference_srv_py_env.sh for Python venv activation
#   - shell_helpers.sh for generic utilities (have_command, run_as_root)
#
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
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
