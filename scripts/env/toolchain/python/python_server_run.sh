#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
LOG_PATH="$project_root/volumes/logs/python_server.log"

mkdir -p "$(dirname "$LOG_PATH")"
if [[ "${FLOX_ENV:-}" == "$project_root"/.flox/run/* || "${FLOX_ENV:-}" == "$project_root"/env/*/.flox/run/* ]]; then
	# shellcheck disable=SC1090
	source "$project_root/scripts/env/toolchain/python/python_env.sh"
	hybrid_ai_activate_python_env
	cd "$project_root/src/python"
	exec python -m hybrid_ai.server "$@" 2>&1 | tee -a "$LOG_PATH"
fi

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc 'project_root="$1"; shift; source "$project_root/scripts/env/toolchain/python/python_env.sh"; hybrid_ai_activate_python_env; cd "$project_root/src/python"; exec python -m hybrid_ai.server "$@"' bash "$project_root" "$@" 2>&1 | tee -a "$LOG_PATH"
