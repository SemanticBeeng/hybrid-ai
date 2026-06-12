#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc '
  project_root="$1"
  shift

  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/inference_srv_py/inference_srv_py_env.sh"
  inference_srv_py_activate_env

  cd "$project_root/src/inference_srv_py"
  exec bash --noprofile --norc -i
' bash "$project_root"