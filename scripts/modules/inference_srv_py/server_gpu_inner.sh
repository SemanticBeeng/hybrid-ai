#!/usr/bin/env bash
# server_gpu_inner.sh — runs inside the activated inference-litert-linux-gpu env.
# The Flox profile has already set litert env vars; ensure venv is active.
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

# Ensure venv is active (profile activation can be unreliable across shell modes).
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"
  inference_srv_py_activate_env
fi

# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/inference/linux_gpu_contract.sh"

hybrid_ai_linux_gpu_contract_check
hybrid_ai_linux_gpu_apply_bridge_env

if [[ -n "${HYBRID_AI_GPU_DEBUG:-}" ]]; then
  snapshot_dir="${HYBRID_AI_GPU_DEBUG_SNAPSHOT_DIR:-/tmp/hybrid-ai-gpu-snapshot-$$}"
  mkdir -p "$snapshot_dir"
  "$project_root/scripts/modules/inference_srv_py/gpu_runtime_snapshot.sh" \
    serve-launch "$snapshot_dir/serve-launch.json" >/dev/null
fi

cd "$project_root/src/inference_srv_py"
exec python -m inference_srv_py.server "$@"
