#!/usr/bin/env bash
# server_gpu_run.sh — outer entry point for GPU inference server.
# Activates the inference-litert-linux-gpu Flox env and exec's the inner script.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOG_PATH="$project_root/volumes/logs/python_server.log"
runtime_env_dir="${HYBRID_AI_LITERT_LINUX_GPU_FLOX_ENV_DIR:-$project_root/env/inference-litert-linux-gpu}"

mkdir -p "$(dirname "$LOG_PATH")"

if [[ "${HYBRID_AI_PYTHON_SERVER_LOG_REDIRECTED:-0}" != "1" ]]; then
  export HYBRID_AI_PYTHON_SERVER_LOG_REDIRECTED=1
  exec >>"$LOG_PATH" 2>&1
fi

# Recover LD_AUDIT from root env when launching from an external shell.
loader_env=()
if [[ -z "${LD_AUDIT:-}" ]]; then
  flox_bin="$(command -v flox 2>/dev/null || echo /opt/bin/dev/nix/bin/flox)"
  if [[ -x "$flox_bin" ]]; then
    while IFS='=' read -r key value; do
      [[ -n "$key" ]] && loader_env+=("$key=$value")
    done < <("$flox_bin" activate -d "$project_root" -- env 2>/dev/null \
      | grep -E '^(LD_AUDIT|GLIBC_TUNABLES)=' || true)
  fi
fi

exec env -u FLOX_ENV -u VIRTUAL_ENV -u VIRTUAL_ENV_PROMPT \
  "${loader_env[@]}" \
  FLOX_ENV_DIR="$runtime_env_dir" \
  FLOX_MANIFEST_PATH="$runtime_env_dir/manifest.toml" \
  "$project_root/scripts/env/toolchain/nix/flox_with.sh" \
  bash -lc 'exec "$1/scripts/modules/inference_srv_py/server_gpu_inner.sh" "${@:2}"' \
  bash "$project_root" "$@"