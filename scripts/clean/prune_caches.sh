#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

exec "$project_root/scripts/env/toolchain/project_cache_cleanup.sh" "$@"
