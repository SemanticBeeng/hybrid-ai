#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc '
  project_root="$1"
  shift

  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/python/python_env.sh"
  hybrid_ai_activate_python_env

  cd "$project_root/src/python"
  exec bash --noprofile --norc -i
' bash "$project_root"