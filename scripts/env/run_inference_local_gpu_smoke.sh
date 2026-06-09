#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec "$project_root/scripts/env/toolchain/python/python_gpu_smoke.sh" "$@"