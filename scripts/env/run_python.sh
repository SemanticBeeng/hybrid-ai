#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON_DIR="$PROJECT_ROOT/src/python"

if [[ $# -eq 0 ]]; then
  set -- -m hybrid_ai
fi

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" poetry -C "$PYTHON_DIR" run python "$@"
