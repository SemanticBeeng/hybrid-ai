#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/nix/nix_flox_env.sh"

if [[ -z "${FLOX_BIN:-}" ]]; then
  echo "ERROR: flox not found. Run scripts/env/toolchain/doctor.sh" >&2
  exit 1
fi

unset VIRTUAL_ENV
unset VIRTUAL_ENV_PROMPT

if [[ $# -eq 0 ]]; then
  cd "$project_root"
  exec "$FLOX_BIN" activate -d "$FLOX_ENV_DIR"
fi

cd "$project_root"
exec "$FLOX_BIN" activate -d "$FLOX_ENV_DIR" -- "$@"
