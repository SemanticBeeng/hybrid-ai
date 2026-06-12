#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
LOG_PATH="$project_root/volumes/logs/python_server.log"
flox_env_dir="$project_root/env/python"

mkdir -p "$(dirname "$LOG_PATH")"
if [[ "${FLOX_ENV:-}" == "$flox_env_dir"/.flox/run/* ]]; then
	# shellcheck disable=SC1090
	source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"
	inference_srv_py_activate_env
	cd "$project_root/src/inference_srv_py"
	exec python -m inference_srv_py.server "$@" 2>&1 | tee -a "$LOG_PATH"
fi

exec env FLOX_ENV_DIR="$flox_env_dir" "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc 'project_root="$1"; shift; source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"; inference_srv_py_activate_env; cd "$project_root/src/inference_srv_py"; exec python -m inference_srv_py.server "$@"' bash "$project_root" "$@" 2>&1 | tee -a "$LOG_PATH"