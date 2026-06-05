#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

exec "$project_root/scripts/env/toolchain/nix/flox_with.sh" bash -lc '
  project_root="$1"
  shift
  source "$project_root/scripts/env/toolchain/swift/swift_env.sh"
  hybrid_ai_activate_swift_env

  printf "project_root=%s\n" "$PWD"
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
  printf "HYBRID_AI_SWIFT_VERSION=%s\n" "${HYBRID_AI_SWIFT_VERSION:-unset}"
  printf "SWIFTLY_ROOT=%s\n" "${SWIFTLY_ROOT:-unset}"
  printf "SWIFTLY_HOME_DIR=%s\n" "${SWIFTLY_HOME_DIR:-unset}"
  printf "SWIFTLY_BIN_DIR=%s\n" "${SWIFTLY_BIN_DIR:-unset}"
  printf "SWIFTLY_TOOLCHAINS_DIR=%s\n" "${SWIFTLY_TOOLCHAINS_DIR:-unset}"
  printf "swift_bin=%s\n" "$(command -v swift)"
  printf "clang_bin=%s\n" "$(command -v clang)"
  printf "sourcekit_lsp_bin=%s\n" "$(command -v sourcekit-lsp || true)"
  printf "lldb_bin=%s\n" "$(command -v lldb || true)"
  swift --version | head -n 1
' bash "$project_root"