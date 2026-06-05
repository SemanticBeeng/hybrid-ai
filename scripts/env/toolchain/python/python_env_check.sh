#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

exec "$PROJECT_ROOT/scripts/env/toolchain/nix/flox_with.sh" bash -lc '
  PROJECT_ROOT="$1"
  shift

  # shellcheck disable=SC1090
  source "$PROJECT_ROOT/scripts/env/toolchain/python/python_env.sh"
  hybrid_ai_activate_python_env

  printf "PROJECT_ROOT=%s\n" "$PROJECT_ROOT"
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
' bash "$PROJECT_ROOT"