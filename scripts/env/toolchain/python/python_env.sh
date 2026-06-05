#!/usr/bin/env bash

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

hybrid_ai_unset_host_python_env() {
  # Prevent an already-active host virtualenv from leaking into repository Python workflows.
  unset VIRTUAL_ENV
  unset VIRTUAL_ENV_PROMPT
}

hybrid_ai_unset_host_python_env

hybrid_ai_python_dir() {
  printf '%s\n' "$project_root/src/python"
}

hybrid_ai_python_venv_dir() {
  if [[ -z "${FLOX_ENV_CACHE:-}" ]]; then
    echo "ERROR: FLOX_ENV_CACHE is required for the managed Python venv." >&2
    return 1
  fi

  printf '%s\n' "$FLOX_ENV_CACHE/python"
}

hybrid_ai_export_python_env() {
  local python_dir=""
  local venv_dir=""

  hybrid_ai_unset_host_python_env

  python_dir="$(hybrid_ai_python_dir)"
  venv_dir="$(hybrid_ai_python_venv_dir)"

  export PYTHON_DIR="$python_dir"
  export HYBRID_AI_PYTHON_VENV="$venv_dir"
  export PIP_CACHE_DIR="$FLOX_ENV_CACHE/pip-cache"
  export POETRY_CACHE_DIR="$FLOX_ENV_CACHE/poetry-cache"
  export UV_CACHE_DIR="$FLOX_ENV_CACHE/uv-cache"
  export PYTHONPYCACHEPREFIX="$FLOX_ENV_CACHE/pycache"
  export PYTHONDONTWRITEBYTECODE=1
  export PIP_DISABLE_PIP_VERSION_CHECK=1
  export POETRY_VIRTUALENVS_CREATE=false

  mkdir -p "$PIP_CACHE_DIR" "$POETRY_CACHE_DIR" "$UV_CACHE_DIR" "$PYTHONPYCACHEPREFIX"
}

hybrid_ai_activate_python_env() {
  local venv_dir=""
  local runtime_dir=""

  hybrid_ai_export_python_env
  venv_dir="$(hybrid_ai_python_venv_dir)"

  if [[ ! -x "$venv_dir/bin/python" ]]; then
    hybrid_ai_setup_python_env
  fi

  if [[ -f "$venv_dir/bin/activate" ]]; then
    # shellcheck disable=SC1090
    . "$venv_dir/bin/activate"
  else
    export VIRTUAL_ENV="$venv_dir"
    export PATH="$venv_dir/bin:$PATH"
  fi

  runtime_dir="$FLOX_ENV/lib"
  if [[ -d "$runtime_dir" ]]; then
    export LD_LIBRARY_PATH="$runtime_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi
}

hybrid_ai_setup_python_env() {
  local python_dir=""
  local venv_dir=""
  local state_dir=""
  local deps_stamp=""
  local current_stamp=""
  local source_file=""

  python_dir="$(hybrid_ai_python_dir)"
  venv_dir="$(hybrid_ai_python_venv_dir)"
  state_dir="$FLOX_ENV_CACHE/state"
  deps_stamp="$state_dir/python-deps.sha256"

  hybrid_ai_export_python_env

  mkdir -p "$state_dir"

  if [[ ! -x "$venv_dir/bin/python" ]]; then
    python -m venv "$venv_dir"
    hybrid_ai_activate_python_env
  fi

  current_stamp="$({
    for source_file in "$python_dir/pyproject.toml" "$python_dir/poetry.lock"; do
      if [[ -f "$source_file" ]]; then
        cat "$source_file"
      fi
    done
  } | sha256sum | awk '{print $1}')"

  if [[ ! -f "$deps_stamp" || "$(cat "$deps_stamp")" != "$current_stamp" ]]; then
    poetry -C "$python_dir" sync --no-interaction
    printf '%s\n' "$current_stamp" > "$deps_stamp"
  fi
}