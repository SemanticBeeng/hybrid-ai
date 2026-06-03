#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_PATH="$PROJECT_ROOT/volumes/logs/python_server.log"
PYTHON_DIR="$PROJECT_ROOT/src/python"

mkdir -p "$(dirname "$LOG_PATH")"
exec "$PROJECT_ROOT/scripts/env/with_flox.sh" poetry -C "$PYTHON_DIR" run python -m hybrid_ai.server "$@" 2>&1 | tee -a "$LOG_PATH"
