#!/usr/bin/env bash

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

hybrid_ai_swift_dir() {
  printf '%s\n' "$PROJECT_ROOT/src/swift"
}

hybrid_ai_swift_wrapper_path() {
  local swift_bin=""

  swift_bin="$(command -v swift 2>/dev/null || true)"
  if [[ -z "$swift_bin" ]]; then
    echo "ERROR: swift is required before activating the Swift environment." >&2
    return 1
  fi

  readlink -f "$swift_bin"
}

hybrid_ai_swift_cc_wrapper_dir() {
  local swift_wrapper=""
  local cc_wrapper=""
  local cc_wrapper_line=""

  swift_wrapper="$(hybrid_ai_swift_wrapper_path)"

  if [[ -r "$swift_wrapper" ]]; then
    cc_wrapper_line="$(grep '^cc_wrapper=' "$swift_wrapper" | head -n 1 || true)"

    if [[ "$cc_wrapper_line" == cc_wrapper=* ]]; then
      cc_wrapper="${cc_wrapper_line#cc_wrapper=\"}"
      cc_wrapper="${cc_wrapper%\"}"

      if [[ "$cc_wrapper" == \$\{NIX_CC:-*\} ]]; then
        cc_wrapper="${cc_wrapper#\$\{NIX_CC:-}"
        cc_wrapper="${cc_wrapper%\}}"
      fi
    fi
  fi

  if [[ -n "$cc_wrapper" && -d "$cc_wrapper/bin" ]]; then
    printf '%s\n' "$cc_wrapper"
    return 0
  fi

  return 1
}

hybrid_ai_export_swift_env() {
  local swift_dir=""
  local cc_wrapper_dir=""

  swift_dir="$(hybrid_ai_swift_dir)"
  export HYBRID_AI_SWIFT_DIR="$swift_dir"

  if cc_wrapper_dir="$(hybrid_ai_swift_cc_wrapper_dir 2>/dev/null)"; then
    export HYBRID_AI_SWIFT_CC_WRAPPER="$cc_wrapper_dir"
  fi
}

hybrid_ai_activate_swift_env() {
  local cc_wrapper_dir=""
  local clang_bin=""
  local clangxx_bin=""

  hybrid_ai_export_swift_env
  cc_wrapper_dir="${HYBRID_AI_SWIFT_CC_WRAPPER:-}"

  if [[ -n "$cc_wrapper_dir" && -d "$cc_wrapper_dir/bin" && ":$PATH:" != *":$cc_wrapper_dir/bin:"* ]]; then
    export PATH="$cc_wrapper_dir/bin:$PATH"
  fi

  clang_bin="$(command -v clang 2>/dev/null || true)"
  clangxx_bin="$(command -v clang++ 2>/dev/null || true)"

  if [[ -n "$clang_bin" ]]; then
    export CC="${CC:-$clang_bin}"
  fi

  if [[ -n "$clangxx_bin" ]]; then
    export CXX="${CXX:-$clangxx_bin}"
  fi
}