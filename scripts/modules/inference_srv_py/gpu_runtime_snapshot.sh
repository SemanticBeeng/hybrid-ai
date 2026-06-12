#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
flox_env_dir="$project_root/env/inference-litert-linux-gpu"

hybrid_ai_python_gpu_runtime_snapshot_inner() {
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference/linux_gpu_contract.sh"

  inference_srv_py_activate_env
  hybrid_ai_linux_gpu_contract_check
  hybrid_ai_linux_gpu_apply_bridge_env
  export HYBRID_AI_LITERT_BACKEND="${HYBRID_AI_LITERT_BACKEND:-gpu}"

  cd "$project_root/src/inference_srv_py"
  exec python -m inference_srv_py.debug_snapshot "$@"
}

if [[ "${FLOX_ENV:-}" == "$flox_env_dir"/.flox/run/* ]]; then
  hybrid_ai_python_gpu_runtime_snapshot_inner "$@"
  exit 0
fi

exec env FLOX_ENV_DIR="$flox_env_dir" \
  "$project_root/scripts/env/toolchain/nix/flox_with.sh" \
  bash -lc 'project_root="$1"; shift; "$project_root/scripts/modules/inference_srv_py/gpu_runtime_snapshot.sh" "$@"' \
  bash "$project_root" "$@"