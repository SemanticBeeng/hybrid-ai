#!/usr/bin/env bash

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

inference_srv_py_unset_host_python_env() {
  # Prevent an already-active host virtualenv from leaking into repository Python workflows.
  unset VIRTUAL_ENV
  unset VIRTUAL_ENV_PROMPT

  # Enforce project isolation by stripping any inherited project-local .venv bins from PATH.
  local root_venv_bin="$project_root/.venv/bin"
  local src_venv_bin="$project_root/src/inference_srv_py/.venv/bin"
  local current_path=":${PATH:-}:"

  current_path="${current_path//:${root_venv_bin}:/:}"
  current_path="${current_path//:${src_venv_bin}:/:}"
  current_path="${current_path#:}"
  current_path="${current_path%:}"
  PATH="$current_path"
  export PATH
}

inference_srv_py_dir() {
  printf '%s\n' "$project_root/src/inference_srv_py"
}

inference_srv_py_venv_dir() {
  if [[ -z "${FLOX_ENV_CACHE:-}" ]]; then
    echo "ERROR: FLOX_ENV_CACHE is required for the managed Python venv." >&2
    return 1
  fi

  printf '%s\n' "$FLOX_ENV_CACHE/python"
}

# inference_srv_py_dedup_colon_path_var() {
#   local var_name="$1"
#   local value="${!var_name:-}"
#   local entry
#   local result=""
#   local seen=""
#
#   if [[ -z "$value" ]]; then
#     return 0
#   fi
#
#   IFS=':' read -r -a entries <<< "$value"
#   for entry in "${entries[@]}"; do
#     [[ -n "$entry" ]] || continue
#     case ":$seen:" in
#       *":$entry:"*)
#         continue
#         ;;
#     esac
#     seen="${seen:+$seen:}$entry"
#     result="${result:+$result:}$entry"
#   done
#
#   printf -v "$var_name" '%s' "$result"
#   export "$var_name"
# }

inference_srv_py_export_env() {
  local python_dir=""
  local venv_dir=""

  inference_srv_py_unset_host_python_env

  python_dir="$(inference_srv_py_dir)"
  venv_dir="$(inference_srv_py_venv_dir)"

  export PYTHON_DIR="$python_dir"
  export HYBRID_AI_PYTHON_VENV="$venv_dir"
  export PIP_CACHE_DIR="$FLOX_ENV_CACHE/pip-cache"
  export POETRY_CACHE_DIR="$FLOX_ENV_CACHE/poetry-cache"
  export UV_CACHE_DIR="$FLOX_ENV_CACHE/uv-cache"
  export PYTHONPYCACHEPREFIX="$FLOX_ENV_CACHE/pycache"
  : "${PYTHONDONTWRITEBYTECODE:=1}"
  : "${PIP_DISABLE_PIP_VERSION_CHECK:=1}"
  : "${POETRY_VIRTUALENVS_CREATE:=false}"
  : "${POETRY_VIRTUALENVS_IN_PROJECT:=false}"
  export PYTHONDONTWRITEBYTECODE PIP_DISABLE_PIP_VERSION_CHECK POETRY_VIRTUALENVS_CREATE POETRY_VIRTUALENVS_IN_PROJECT

  mkdir -p "$PIP_CACHE_DIR" "$POETRY_CACHE_DIR" "$UV_CACHE_DIR" "$PYTHONPYCACHEPREFIX"
}

inference_srv_py_activate_env() {
  local venv_dir=""

  inference_srv_py_export_env
  venv_dir="$(inference_srv_py_venv_dir)"

  if [[ ! -x "$venv_dir/bin/python" ]]; then
    inference_srv_py_setup_env
  fi

  if [[ -f "$venv_dir/bin/activate" ]]; then
    # shellcheck disable=SC1090
    . "$venv_dir/bin/activate"
  else
    export VIRTUAL_ENV="$venv_dir"
    export PATH="$venv_dir/bin:$PATH"
  fi

  # Dedup unnecessary: _unset_host_python_env already strips stale entries and
  # bin/activate guards against double-activation via VIRTUAL_ENV.
  # inference_srv_py_dedup_colon_path_var PATH
}

inference_srv_py_setup_env() {
  local python_dir=""
  local venv_dir=""
  local state_dir=""
  local deps_stamp=""
  local current_stamp=""
  local source_file=""

  python_dir="$(inference_srv_py_dir)"
  venv_dir="$(inference_srv_py_venv_dir)"
  state_dir="$FLOX_ENV_CACHE/state"
  deps_stamp="$state_dir/python-deps.sha256"

  inference_srv_py_export_env

  mkdir -p "$state_dir"

  if [[ ! -x "$venv_dir/bin/python" ]]; then
    python -m venv "$venv_dir"
    inference_srv_py_activate_env
  fi

  current_stamp="$({
    printf '%s\n' "$python_dir"
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