#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_PATH="$PROJECT_ROOT/volumes/logs/python_server.log"

mkdir -p "$(dirname "$LOG_PATH")"
if [[ -n "${FLOX_ENV:-}" ]]; then
	# shellcheck disable=SC1090
	source "$PROJECT_ROOT/scripts/env/toolchain/python_env.sh"
	hybrid_ai_activate_python_env
	cd "$PROJECT_ROOT/src/python"
	exec python -m hybrid_ai.server "$@" 2>&1 | tee -a "$LOG_PATH"
fi

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" bash -lc 'PROJECT_ROOT="$1"; shift; source "$PROJECT_ROOT/scripts/env/toolchain/python_env.sh"; hybrid_ai_activate_python_env; cd "$PROJECT_ROOT/src/python"; exec python -m hybrid_ai.server "$@"' bash "$PROJECT_ROOT" "$@" 2>&1 | tee -a "$LOG_PATH"
