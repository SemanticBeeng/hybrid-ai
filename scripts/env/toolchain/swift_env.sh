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

hybrid_ai_sanitize_swift_ld_library_path() {
  local flox_lib=""
  local sanitized=""
  local entry=""

  export HYBRID_AI_ORIGINAL_LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"

  if [[ -n "${FLOX_ENV:-}" ]]; then
    flox_lib="$FLOX_ENV/lib"
  fi

  IFS=':' read -r -a ld_entries <<< "${LD_LIBRARY_PATH:-}"
  for entry in "${ld_entries[@]}"; do
    [[ -n "$entry" ]] || continue
    if [[ -n "$flox_lib" && "$entry" == "$flox_lib" ]]; then
      continue
    fi
    case "$entry" in
      /nix/store/*glibc*|/nix/store/*gcc*|/nix/store/*swift*|/nix/store/*dispatch*|/nix/store/*foundation*)
        continue
        ;;
    esac
    sanitized="${sanitized:+$sanitized:}$entry"
  done

  if [[ -n "$sanitized" ]]; then
    export LD_LIBRARY_PATH="$sanitized"
  else
    unset LD_LIBRARY_PATH
  fi
}

hybrid_ai_activate_swift_env() {
  local clang_bin=""
  local clangxx_bin=""

  hybrid_ai_export_swift_env
  hybrid_ai_source_swiftly_env
  hybrid_ai_assert_swift_version
  hybrid_ai_sanitize_swift_ld_library_path

  clang_bin="$(command -v clang 2>/dev/null || true)"
  clangxx_bin="$(command -v clang++ 2>/dev/null || true)"

  if [[ -n "$clang_bin" ]]; then
    export CC="${CC:-$clang_bin}"
  fi

  if [[ -n "$clangxx_bin" ]]; then
    export CXX="${CXX:-$clangxx_bin}"
  fi
}