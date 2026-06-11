#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
runtime_env_dir="${HYBRID_AI_LITERT_LINUX_GPU_FLOX_ENV_DIR:-${HYBRID_AI_PYTHON_FLOX_ENV_DIR:-$project_root/env/inference-litert-linux-gpu}}"
runtime_manifest_path="$runtime_env_dir/manifest.toml"

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

if [[ "${FLOX_ENV:-}" == "$runtime_env_dir"/.flox/run/* ]]; then
  hybrid_ai_python_gpu_runtime_snapshot_inner "$@"
  exit 0
fi

exec env FLOX_ENV_DIR="$runtime_env_dir" FLOX_MANIFEST_PATH="$runtime_manifest_path" \
  "$project_root/scripts/env/toolchain/nix/flox_with.sh" \
  bash -lc 'project_root="$1"; shift; "$project_root/scripts/modules/inference_srv_py/gpu_runtime_snapshot.sh" "$@"' \
  bash "$project_root" "$@"