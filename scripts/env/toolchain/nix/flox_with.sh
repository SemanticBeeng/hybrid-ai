#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

use_nix_daemon
ensure_nix_bind_mount
require_nix_daemon_socket

FLOX_BIN="$(require_flox_bin)"

unset VIRTUAL_ENV
unset VIRTUAL_ENV_PROMPT

hybrid_ai_require_flox_env "$FLOX_ENV_DIR"

if [[ $# -eq 0 ]]; then
  cd "$PROJECT_ROOT"
  exec "$FLOX_BIN" activate -d "$FLOX_ENV_DIR"
fi

cd "$PROJECT_ROOT"
exec "$FLOX_BIN" activate -d "$FLOX_ENV_DIR" -- "$@"
