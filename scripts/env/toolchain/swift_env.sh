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

hybrid_ai_ensure_pkg_config_module() {
  local module="$1"
  local pc_file=""
  local pc_dir=""

  if ! command -v pkg-config >/dev/null 2>&1; then
    return 1
  fi

  if pkg-config --exists "$module"; then
    return 0
  fi

  pc_file="$(find /nix/store \( -path "*/lib/pkgconfig/$module.pc" -o -path "*/share/pkgconfig/$module.pc" \) 2>/dev/null | head -n 1 || true)"
  if [[ -z "$pc_file" ]]; then
    return 1
  fi

  pc_dir="$(dirname "$pc_file")"
  export PKG_CONFIG_PATH="$pc_dir${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  pkg-config --exists "$module"
}

hybrid_ai_export_gtk_pkg_config_path() {
  local module=""
  local modules=(libsepol libselinux mount fribidi datrie-0.2 libthai expat xdmcp libdeflate Lerc liblzma)

  for module in "${modules[@]}"; do
    hybrid_ai_ensure_pkg_config_module "$module" || true
  done
}

hybrid_ai_export_gtk_env() {
  local modules=""

  modules="${HYBRID_AI_GTK_PKG_CONFIG_MODULES:-gtk4 libadwaita-1}"
  export HYBRID_AI_GTK_PKG_CONFIG_MODULES="$modules"

  if ! command -v pkg-config >/dev/null 2>&1; then
    return 0
  fi

  hybrid_ai_export_gtk_pkg_config_path

  if ! pkg-config --exists $modules; then
    return 0
  fi

  export HYBRID_AI_GTK_CFLAGS="$(pkg-config --cflags $modules)"
  export HYBRID_AI_GTK_LIBS="$(pkg-config --libs $modules)"
  export HYBRID_AI_GTK_LIB_DIRS="$(pkg-config --libs-only-L $modules | sed 's/-L//g')"
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
  local swiftly_toolchain_bin=""

  hybrid_ai_export_swift_env
  hybrid_ai_source_swiftly_env
  hybrid_ai_assert_swift_version
  hybrid_ai_sanitize_swift_ld_library_path

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

hybrid_ai_activate_swift_gtk_env() {
  hybrid_ai_activate_swift_env
  hybrid_ai_export_gtk_env
}