#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" bash -lc '
  PROJECT_ROOT="$1"
  shift
  source "$PROJECT_ROOT/scripts/env/toolchain/swift_env.sh"
  hybrid_ai_activate_swift_env

  printf "PROJECT_ROOT=%s\n" "$PWD"
  printf "FLOX_ENV=%s\n" "${FLOX_ENV:-unset}"
  printf "HOME=%s\n" "$HOME"
  printf "XDG_CONFIG_HOME=%s\n" "$XDG_CONFIG_HOME"
  printf "XDG_CACHE_HOME=%s\n" "$XDG_CACHE_HOME"
  printf "XDG_DATA_HOME=%s\n" "$XDG_DATA_HOME"
  printf "XDG_STATE_HOME=%s\n" "$XDG_STATE_HOME"
  printf "SWIFT_BUILD_PATH=%s\n" "$SWIFT_BUILD_PATH"
  printf "CLANG_MODULE_CACHE_PATH=%s\n" "$CLANG_MODULE_CACHE_PATH"
  printf "SWIFTPM_PACKAGECACHE=%s\n" "$SWIFTPM_PACKAGECACHE"
  printf "HYBRID_AI_SWIFT_DIR=%s\n" "${HYBRID_AI_SWIFT_DIR:-unset}"
  printf "HYBRID_AI_SWIFT_CC_WRAPPER=%s\n" "${HYBRID_AI_SWIFT_CC_WRAPPER:-unset}"
  printf "swift_bin=%s\n" "$(command -v swift)"
  printf "clang_bin=%s\n" "$(command -v clang)"
  swift --version | head -n 1
' bash "$PROJECT_ROOT"