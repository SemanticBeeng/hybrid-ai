#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

if [[ $# -eq 0 ]]; then
  set -- -m hybrid_ai
fi

if [[ -n "${FLOX_ENV:-}" ]]; then
  # shellcheck disable=SC1090
  source "$PROJECT_ROOT/scripts/env/toolchain/python/python_env.sh"
  hybrid_ai_activate_python_env
  cd "$PROJECT_ROOT/src/python"
  exec python "$@"
fi

exec "$PROJECT_ROOT/scripts/env/toolchain/nix/flox_with.sh" bash -lc 'PROJECT_ROOT="$1"; shift; source "$PROJECT_ROOT/scripts/env/toolchain/python/python_env.sh"; hybrid_ai_activate_python_env; cd "$PROJECT_ROOT/src/python"; exec python "$@"' bash "$PROJECT_ROOT" "$@"
