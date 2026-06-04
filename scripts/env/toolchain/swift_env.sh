#!/usr/bin/env bash

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

# shellcheck disable=SC1090
source "$PROJECT_ROOT/scripts/env/toolchain/swiftly_common.sh"

hybrid_ai_swift_dir() {
  printf '%s\n' "$PROJECT_ROOT/src/swift"
}

hybrid_ai_export_swift_env() {
  local swift_dir=""

  swift_dir="$(hybrid_ai_swift_dir)"
  export HYBRID_AI_SWIFT_DIR="$swift_dir"
}

hybrid_ai_activate_swift_env() {
  local clang_bin=""
  local clangxx_bin=""

  hybrid_ai_export_swift_env
  hybrid_ai_source_swiftly_env
  hybrid_ai_assert_swift_version

  clang_bin="$(command -v clang 2>/dev/null || true)"
  clangxx_bin="$(command -v clang++ 2>/dev/null || true)"

  if [[ -n "$clang_bin" ]]; then
    export CC="${CC:-$clang_bin}"
  fi

  if [[ -n "$clangxx_bin" ]]; then
    export CXX="${CXX:-$clangxx_bin}"
  fi
}