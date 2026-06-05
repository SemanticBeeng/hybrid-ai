#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$project_root/scripts/env/toolchain/common.sh"

use_nix_daemon
ensure_nix_bind_mount
require_nix_daemon_socket

FLOX_BIN="$(require_flox_bin)"

unset VIRTUAL_ENV
unset VIRTUAL_ENV_PROMPT

hybrid_ai_require_flox_env "$FLOX_ENV_DIR"

if [[ $# -eq 0 ]]; then
  cd "$project_root"
  exec "$FLOX_BIN" activate -d "$FLOX_ENV_DIR"
fi

cd "$project_root"
exec "$FLOX_BIN" activate -d "$FLOX_ENV_DIR" -- "$@"
