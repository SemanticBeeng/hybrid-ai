#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc '
  project_root="$1"
  shift

  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"
  inference_srv_py_activate_env

  printf "project_root=%s\n" "$project_root"
  printf "FLOX_ENV=%s\n" "${FLOX_ENV:-unset}"
  printf "FLOX_ENV_CACHE=%s\n" "${FLOX_ENV_CACHE:-unset}"
  printf "PYTHON_DIR=%s\n" "$PYTHON_DIR"
  printf "HYBRID_AI_PYTHON_VENV=%s\n" "$HYBRID_AI_PYTHON_VENV"
  printf "VIRTUAL_ENV=%s\n" "${VIRTUAL_ENV:-unset}"
  printf "POETRY_VIRTUALENVS_CREATE=%s\n" "${POETRY_VIRTUALENVS_CREATE:-unset}"
  printf "PIP_CACHE_DIR=%s\n" "$PIP_CACHE_DIR"
  printf "POETRY_CACHE_DIR=%s\n" "$POETRY_CACHE_DIR"
  printf "UV_CACHE_DIR=%s\n" "$UV_CACHE_DIR"
  printf "PYTHONPYCACHEPREFIX=%s\n" "$PYTHONPYCACHEPREFIX"
  printf "LD_LIBRARY_PATH=%s\n" "${LD_LIBRARY_PATH:-unset}"
  python - <<"PY"
import os
import sys
print(f"sys.executable={sys.executable}")
print(f"python_bin_dir={os.path.dirname(sys.executable)}")
PY
' bash "$project_root"