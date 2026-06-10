#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOG_PATH="$project_root/volumes/logs/python_server.log"
runtime_env_dir="${HYBRID_AI_LITERT_LINUX_GPU_FLOX_ENV_DIR:-${HYBRID_AI_PYTHON_FLOX_ENV_DIR:-$project_root/env/inference-litert-linux-gpu}}"
runtime_manifest_path="$runtime_env_dir/manifest.toml"

hybrid_ai_python_server_restore_flox_loader_state() {
  local needs_restore=0
  local line
  local key
  local value
  local flox_bin

  [[ -n "${LD_AUDIT:-}" ]] || needs_restore=1
  [[ -n "${GLIBC_TUNABLES:-}" ]] || needs_restore=1

  [[ "$needs_restore" -eq 1 ]] || return 0

  flox_bin="$(command -v flox 2>/dev/null || echo "$FLOX_WRAPPER_BIN")"
  [[ -x "$flox_bin" ]] || return 0

  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      LD_AUDIT|SANDBOX_LD_AUDIT|GLIBC_TUNABLES)
        export "$key=$value"
        ;;
    esac
  done < <(
    "$flox_bin" activate -d "$project_root" -- env \
      2>/dev/null \
      | grep -E '^(LD_AUDIT|SANDBOX_LD_AUDIT|GLIBC_TUNABLES)=' || true
  )
}

hybrid_ai_python_server_setup_logging() {
  mkdir -p "$(dirname "$LOG_PATH")"

  if [[ "${HYBRID_AI_PYTHON_SERVER_LOG_REDIRECTED:-0}" == "1" ]]; then
    return 0
  fi

  export HYBRID_AI_PYTHON_SERVER_LOG_REDIRECTED=1
  exec >>"$LOG_PATH" 2>&1
}

hybrid_ai_python_server_gpu_inner() {
  local snapshot_dir="${HYBRID_AI_GPU_DEBUG_SNAPSHOT_DIR:-}"

  hybrid_ai_python_server_setup_logging

  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_env.sh"
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference/linux_gpu_contract.sh"

  hybrid_ai_linux_gpu_scrub_runtime_env
  inference_srv_py_activate_env
  hybrid_ai_python_server_restore_flox_loader_state
  hybrid_ai_linux_gpu_contract_check
  hybrid_ai_linux_gpu_apply_bridge_env
  export HYBRID_AI_LITERT_BACKEND=gpu

  "$project_root/scripts/modules/inference_srv_py/gpu_validate.sh"

  if [[ -n "$snapshot_dir" ]]; then
    mkdir -p "$snapshot_dir"
    "$project_root/scripts/modules/inference_srv_py/gpu_runtime_snapshot.sh" \
      serve-launch "$snapshot_dir/serve-launch.json" >/dev/null
  fi

  cd "$project_root/src/inference_srv_py"
  exec python -m inference_srv_py.server "$@"
}

if [[ "${FLOX_ENV:-}" == "$runtime_env_dir"/.flox/run/* ]]; then
  hybrid_ai_python_server_gpu_inner "$@"
  exit 0
fi

hybrid_ai_python_server_setup_logging
exec env -u FLOX_ENV -u VIRTUAL_ENV -u VIRTUAL_ENV_PROMPT \
  FLOX_ENV_DIR="$runtime_env_dir" FLOX_MANIFEST_PATH="$runtime_manifest_path" \
  "$project_root/scripts/env/toolchain/nix/flox_with.sh" \
  bash -lc 'project_root="$1"; shift; "$project_root/scripts/modules/inference_srv_py/server_gpu_run.sh" "$@"' \
  bash "$project_root" "$@"