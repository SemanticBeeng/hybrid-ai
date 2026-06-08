#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${HYBRID_AI_BACKEND_BASE_URL:=http://127.0.0.1:8080}"
export HYBRID_AI_BACKEND_BASE_URL

exec "$project_root/scripts/env/toolchain/swift/swift_run.sh" test --filter liveBackend