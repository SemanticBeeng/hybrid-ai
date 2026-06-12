#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

: "${HYBRID_AI_BACKEND_BASE_URL:=http://127.0.0.1:8080}"
export HYBRID_AI_BACKEND_BASE_URL

exec "$project_root/scripts/modules/swift/run.sh" test --filter liveBackend