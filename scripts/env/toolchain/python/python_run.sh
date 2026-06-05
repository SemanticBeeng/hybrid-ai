#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

if [[ $# -eq 0 ]]; then
  set -- -m hybrid_ai
fi

if [[ "${FLOX_ENV:-}" == "$project_root"/.flox/run/* || "${FLOX_ENV:-}" == "$project_root"/env/*/.flox/run/* ]]; then
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/python/python_env.sh"
  hybrid_ai_activate_python_env
  cd "$project_root/src/python"
  exec python "$@"
fi

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc 'project_root="$1"; shift; source "$project_root/scripts/env/toolchain/python/python_env.sh"; hybrid_ai_activate_python_env; cd "$project_root/src/python"; exec python "$@"' bash "$project_root" "$@"
