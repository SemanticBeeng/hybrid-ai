#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_PATH="$PROJECT_ROOT/volumes/logs/python_server.log"

mkdir -p "$(dirname "$LOG_PATH")"
exec "$PROJECT_ROOT/scripts/env/with_flox.sh" python -m hybrid_ai.server "$@" 2>&1 | tee -a "$LOG_PATH"
