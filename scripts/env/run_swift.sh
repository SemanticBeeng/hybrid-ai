#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SWIFT_PACKAGE_DIR="$PROJECT_ROOT/src/swift"

if [[ $# -eq 0 ]]; then
  set -- build
fi

SWIFT_SUBCOMMAND="$1"
shift

swift_cmd=(
  swift "$SWIFT_SUBCOMMAND"
  --package-path "$SWIFT_PACKAGE_DIR"
  --build-path "$PROJECT_ROOT/build/swift"
  "$@"
)

if [[ -n "${FLOX_ENV:-}" ]]; then
  # shellcheck disable=SC1090
  source "$PROJECT_ROOT/scripts/env/toolchain/swift_env.sh"
  hybrid_ai_activate_swift_env
  exec "${swift_cmd[@]}"
fi

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" bash -lc '
  PROJECT_ROOT="$1"
  shift
  source "$PROJECT_ROOT/scripts/env/toolchain/swift_env.sh"
  hybrid_ai_activate_swift_env
  exec "$@"
' bash "$PROJECT_ROOT" "${swift_cmd[@]}"
