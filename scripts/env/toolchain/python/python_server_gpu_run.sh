#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
LOG_PATH="$project_root/volumes/logs/python_server.log"
python_env_dir="${HYBRID_AI_PYTHON_FLOX_ENV_DIR:-$project_root/env/python}"
python_manifest_path="$python_env_dir/manifest.toml"

hybrid_ai_python_server_gpu_inner() {
  mkdir -p "$(dirname "$LOG_PATH")"

  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/python/python_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference/linux_gpu_contract.sh"

  hybrid_ai_activate_python_env
  hybrid_ai_linux_gpu_contract_check
  hybrid_ai_linux_gpu_apply_bridge_env
  export HYBRID_AI_LITERT_BACKEND=gpu

  "$project_root/scripts/env/toolchain/python/python_gpu_validate.sh"

  cd "$project_root/src/python"
  exec python -m hybrid_ai.server "$@" 2>&1 | tee -a "$LOG_PATH"
}

if [[ "${FLOX_ENV:-}" == "$python_env_dir"/.flox/run/* ]]; then
  hybrid_ai_python_server_gpu_inner "$@"
  exit 0
fi

mkdir -p "$(dirname "$LOG_PATH")"
exec env FLOX_ENV_DIR="$python_env_dir" FLOX_MANIFEST_PATH="$python_manifest_path" \
  "$project_root/scripts/env/toolchain/nix/flox_with.sh" \
  bash -lc 'project_root="$1"; shift; "$project_root/scripts/env/toolchain/python/python_server_gpu_run.sh" "$@"' \
  bash "$project_root" "$@" 2>&1 | tee -a "$LOG_PATH"