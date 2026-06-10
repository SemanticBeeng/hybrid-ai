#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
runtime_env_dir="${HYBRID_AI_LITERT_LINUX_GPU_FLOX_ENV_DIR:-${HYBRID_AI_PYTHON_FLOX_ENV_DIR:-$project_root/env/inference-litert-linux-gpu}}"
runtime_manifest_path="$runtime_env_dir/manifest.toml"

hybrid_ai_python_gpu_runtime_snapshot_inner() {
  local label="${1:-snapshot}"
  local output_path="${2:-}"

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
  python - "$label" "$output_path" <<'PY'
from __future__ import annotations

import ctypes.util
import json
import os
import platform
import sys
from pathlib import Path

from inference_srv_py.bootstrap import load_bootstrap_state


def collect() -> dict[str, object]:
    state = load_bootstrap_state()
    litert_path = None
    litert_import_error = None
    try:
        import litert_lm  # type: ignore

        litert_path = getattr(litert_lm, "__file__", None)
    except Exception as exc:  # pragma: no cover - debug path
        litert_import_error = str(exc)

    env_keys = [
        "FLOX_ENV",
        "FLOX_ENV_CACHE",
        "HYBRID_AI_LITERT_BACKEND",
        "HYBRID_AI_LITERT_MODEL",
        "HYBRID_AI_LITERT_MODEL_PATH",
        "HYBRID_AI_LITERT_MODEL_FILE",
        "HYBRID_AI_GPU_DEVICE_NODES",
        "HYBRID_AI_GPU_ICD_FILES",
        "HYBRID_AI_GPU_VENDOR_LIBRARIES",
        "HYBRID_AI_GPU_HOST_LIB_DIRS",
        "VK_ICD_FILENAMES",
        "LD_LIBRARY_PATH",
        "PATH",
    ]
    env_subset = {key: os.environ.get(key) for key in env_keys}

    return {
        "label": sys.argv[1],
        "pid": os.getpid(),
        "cwd": os.getcwd(),
        "platform": platform.platform(),
        "python_executable": sys.executable,
        "python_prefix": sys.prefix,
        "python_version": sys.version,
        "libvulkan": ctypes.util.find_library("vulkan"),
        "litert_lm_file": litert_path,
        "litert_lm_import_error": litert_import_error,
        "env": env_subset,
        "bootstrap": {
            "runtime_version": state.runtime_version,
            "model_reference": state.model_reference,
            "model_directory": str(state.model_directory),
            "model_file": str(state.model_file) if state.model_file else None,
            "issues": list(state.issues),
        },
    }


payload = collect()
body = json.dumps(payload, indent=2, sort_keys=True)
output_path = sys.argv[2]
if output_path:
    Path(output_path).write_text(body + "\n", encoding="utf-8")
print(body)
PY
}

if [[ "${FLOX_ENV:-}" == "$runtime_env_dir"/.flox/run/* ]]; then
  hybrid_ai_python_gpu_runtime_snapshot_inner "$@"
  exit 0
fi

exec env FLOX_ENV_DIR="$runtime_env_dir" FLOX_MANIFEST_PATH="$runtime_manifest_path" \
  "$project_root/scripts/env/toolchain/nix/flox_with.sh" \
  bash -lc 'project_root="$1"; shift; "$project_root/scripts/modules/inference_srv_py/gpu_runtime_snapshot.sh" "$@"' \
  bash "$project_root" "$@"