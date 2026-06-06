#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SWIFT_PACKAGE_DIR="$project_root/src/swift"

if [[ $# -eq 0 ]]; then
  set -- build
fi

SWIFT_SUBCOMMAND="$1"
shift

swift_cmd=(
  swift "$SWIFT_SUBCOMMAND"
  --package-path "$SWIFT_PACKAGE_DIR"
  --build-path "$project_root/build/swift"
  "$@"
)

if [[ "${FLOX_ENV:-}" == "$project_root"/.flox/run/* || "${FLOX_ENV:-}" == "$project_root"/env/*/.flox/run/* ]]; then
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/swift/swift_env.sh"
  hybrid_ai_activate_swift_env
  exec "${swift_cmd[@]}"
fi

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc '
  project_root="$1"
  shift
  source "$project_root/scripts/env/toolchain/swift/swift_env.sh"
  hybrid_ai_activate_swift_env
  exec "$@"
' bash "$project_root" "${swift_cmd[@]}"
