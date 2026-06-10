#!/usr/bin/env bash

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/swift/swift_paths.sh"
# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/swift/swiftly_common.sh"

hybrid_ai_swift_dir() {
  printf '%s\n' "$project_root/src/swift"
}

hybrid_ai_export_swift_env() {
  local swift_dir=""

  swift_dir="$(hybrid_ai_swift_dir)"
  export HYBRID_AI_SWIFT_DIR="$swift_dir"
}

hybrid_ai_sanitize_swift_ld_library_path() {
  unset LD_LIBRARY_PATH
}

hybrid_ai_activate_swift_env() {
  local clang_bin=""
  local clangxx_bin=""
  local swiftly_toolchain_bin=""

  hybrid_ai_export_swift_env
  hybrid_ai_source_swiftly_env
  hybrid_ai_assert_swift_version
  hybrid_ai_sanitize_swift_ld_library_path

  case "${SWIFTLY_TOOLCHAINS_DIR:-}" in
    "$SWIFTLY_ROOT"/*) ;;
    *)
      echo "ERROR: SWIFTLY_TOOLCHAINS_DIR must stay under SWIFTLY_ROOT, got: ${SWIFTLY_TOOLCHAINS_DIR:-unset}" >&2
      return 1
      ;;
  esac

  swiftly_toolchain_bin="${SWIFTLY_TOOLCHAINS_DIR:-}/$HYBRID_AI_SWIFT_VERSION/usr/bin"

  if [[ -x "$swiftly_toolchain_bin/clang" ]]; then
    clang_bin="$swiftly_toolchain_bin/clang"
  else
    clang_bin="$(command -v clang 2>/dev/null || true)"
  fi

  if [[ -x "$swiftly_toolchain_bin/clang++" ]]; then
    clangxx_bin="$swiftly_toolchain_bin/clang++"
  else
    clangxx_bin="$(command -v clang++ 2>/dev/null || true)"
  fi

  if [[ -n "$clang_bin" ]]; then
    if [[ -z "${CC:-}" || "${CC:-}" == "$SWIFTLY_BIN_DIR/clang" ]]; then
      export CC="$clang_bin"
    fi
  fi

  if [[ -n "$clangxx_bin" ]]; then
    if [[ -z "${CXX:-}" || "${CXX:-}" == "$SWIFTLY_BIN_DIR/clang++" ]]; then
      export CXX="$clangxx_bin"
    fi
  fi
}