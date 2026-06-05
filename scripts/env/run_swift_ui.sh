#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SWIFT_PACKAGE_DIR="$PROJECT_ROOT/src/swift"
HYBRID_AI_SWIFT_UI_PRODUCT="${HYBRID_AI_SWIFT_UI_PRODUCT:-hybrid-ai-mobile-chat}"

if [[ $# -eq 0 ]]; then
  set -- build --product "$HYBRID_AI_SWIFT_UI_PRODUCT"
fi

SWIFT_SUBCOMMAND="$1"
shift

run_swift_ui_command='PROJECT_ROOT="$1"
SWIFT_PACKAGE_DIR="$2"
SWIFT_SUBCOMMAND="$3"
shift 3
source "$PROJECT_ROOT/scripts/env/toolchain/swift_env.sh"
hybrid_ai_activate_swift_env
export HYBRID_AI_ENABLE_GTK_UI=1

if ! command -v pkg-config >/dev/null 2>&1; then
  echo "ERROR: pkg-config is required for the GTK/libadwaita Swift UI workflow." >&2
  exit 1
fi

ensure_pkg_config_module() {
  local module="$1"
  local pc_file=""
  local pc_dir=""

  if pkg-config --exists "$module"; then
    return 0
  fi

  pc_file="$(find /nix/store -path "*/lib/pkgconfig/$module.pc" -o -path "*/share/pkgconfig/$module.pc" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$pc_file" ]]; then
    return 1
  fi

  pc_dir="$(dirname "$pc_file")"
  export PKG_CONFIG_PATH="$pc_dir${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  pkg-config --exists "$module"
}

ensure_pkg_config_module libsepol || true
ensure_pkg_config_module libselinux || true
ensure_pkg_config_module mount || true
ensure_pkg_config_module fribidi || true
ensure_pkg_config_module datrie-0.2 || true
ensure_pkg_config_module libthai || true

pkg_config_modules=(gtk4 libadwaita-1)
for module in "${pkg_config_modules[@]}"; do
  if ! pkg-config --exists "$module"; then
    echo "ERROR: missing pkg-config module: $module" >&2
    echo "Install GTK/libadwaita through env/swift/manifest.toml and re-sync Flox." >&2
    exit 1
  fi
done

swiftpm_flags=()
for flag in $(pkg-config --cflags "${pkg_config_modules[@]}"); do
  swiftpm_flags+=("-Xcc" "$flag")
done
for flag in $(pkg-config --libs "${pkg_config_modules[@]}"); do
  swiftpm_flags+=("-Xlinker" "$flag")
done

gtk_runtime_glibc_lib_dir() {
  local glibc_lib=""
  local gtk_runtime_lib=""
  local discovered=""

  if [[ -n "${HYBRID_AI_SWIFT_UI_GLIBC_LIB_DIR:-}" ]]; then
    if [[ -x "$HYBRID_AI_SWIFT_UI_GLIBC_LIB_DIR/ld-linux-x86-64.so.2" || -x "$HYBRID_AI_SWIFT_UI_GLIBC_LIB_DIR/ld-linux-aarch64.so.1" ]]; then
      printf "%s\n" "$HYBRID_AI_SWIFT_UI_GLIBC_LIB_DIR"
      return 0
    fi
  fi

  if [[ -n "${FLOX_ENV:-}" ]]; then
    gtk_runtime_lib="$(realpath "$FLOX_ENV/lib/libglib-2.0.so.0" 2>/dev/null || true)"
    if [[ -n "$gtk_runtime_lib" && -r "$gtk_runtime_lib" ]]; then
      discovered="$(readelf -d "$gtk_runtime_lib" 2>/dev/null | grep -oE "/nix/store/[^:]]+-glibc-[^:/]+/lib" | head -n 1 || true)"
      if [[ -z "$discovered" ]]; then
        discovered="$(strings "$gtk_runtime_lib" 2>/dev/null | grep -oE "/nix/store/[^:]]+-glibc-[^:/]+/lib" | head -n 1 || true)"
      fi
      if [[ -n "$discovered" ]]; then
        printf "%s\n" "$discovered"
        return 0
      fi
    fi
  fi

  glibc_lib="$(find /nix/store -path "*/lib/libresolv.so.2" 2>/dev/null | grep -- "-glibc-" | sort -V | tail -n 1 || true)"
  if [[ -z "$glibc_lib" ]]; then
    return 1
  fi

  dirname "$glibc_lib"
}

gtk_runtime_library_path() {
  local runtime_path=""
  local glibc_lib=""
  local swift_lib=""
  local flag=""
  local lib_dir=""

  glibc_lib="$(gtk_runtime_glibc_lib_dir || true)"
  if [[ -n "$glibc_lib" ]]; then
    runtime_path="$glibc_lib"
  fi

  swift_lib="${SWIFTLY_TOOLCHAINS_DIR:-}/$HYBRID_AI_SWIFT_VERSION/usr/lib/swift/linux"
  if [[ -d "$swift_lib" ]]; then
    runtime_path="${runtime_path:+$runtime_path:}$swift_lib"
  fi

  for flag in $(pkg-config --libs-only-L "${pkg_config_modules[@]}"); do
    lib_dir="${flag#-L}"
    [[ -d "$lib_dir" ]] || continue
    runtime_path="${runtime_path:+$runtime_path:}$lib_dir"
  done

  if [[ -n "${FLOX_ENV:-}" && -d "$FLOX_ENV/lib" ]]; then
    runtime_path="${runtime_path:+$runtime_path:}$FLOX_ENV/lib"
  fi

  printf "%s\n" "$runtime_path"
}

gtk_runtime_loader() {
  local glibc_lib=""
  local loader=""

  glibc_lib="$(gtk_runtime_glibc_lib_dir || true)"
  if [[ -z "$glibc_lib" ]]; then
    return 1
  fi

  case "$(uname -m)" in
    x86_64) loader="$glibc_lib/ld-linux-x86-64.so.2" ;;
    aarch64) loader="$glibc_lib/ld-linux-aarch64.so.1" ;;
    *) return 1 ;;
  esac

  [[ -x "$loader" ]] || return 1
  printf "%s\n" "$loader"
}

if [[ "$SWIFT_SUBCOMMAND" == "run" ]]; then
  product="${1:-$HYBRID_AI_SWIFT_UI_PRODUCT}"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  swift build \
    --package-path "$SWIFT_PACKAGE_DIR" \
    --build-path "$PROJECT_ROOT/build/swift" \
    "${swiftpm_flags[@]}" \
    --product "$product"

  bin_path="$(swift build \
    --package-path "$SWIFT_PACKAGE_DIR" \
    --build-path "$PROJECT_ROOT/build/swift" \
    --show-bin-path)"

  runtime_path="$(gtk_runtime_library_path)"
  runtime_loader="$(gtk_runtime_loader || true)"

  if [[ -z "$runtime_loader" ]]; then
    echo "ERROR: unable to locate matching Nix glibc dynamic loader for GTK UI runtime." >&2
    echo "Refusing to run $product directly because that can mix host libc with Nix/Flox GTK libraries." >&2
    exit 1
  fi

  if [[ "${HYBRID_AI_SWIFT_UI_PRINT_RUNTIME:-}" == "1" ]]; then
    printf "runtime_loader=%s\n" "$runtime_loader" >&2
    printf "runtime_library_path=%s\n" "$runtime_path" >&2
    printf "runtime_binary=%s\n" "$bin_path/$product" >&2
  fi

  export GTK_A11Y="${GTK_A11Y:-none}"
  unset LD_AUDIT
  unset LD_PRELOAD
  exec "$runtime_loader" --library-path "$runtime_path" "$bin_path/$product" "$@"
fi

exec swift "$SWIFT_SUBCOMMAND" \
  --package-path "$SWIFT_PACKAGE_DIR" \
  --build-path "$PROJECT_ROOT/build/swift" \
  "${swiftpm_flags[@]}" \
  "$@"'

if [[ -n "${FLOX_ENV:-}" ]]; then
  exec bash -lc "$run_swift_ui_command" bash "$PROJECT_ROOT" "$SWIFT_PACKAGE_DIR" "$SWIFT_SUBCOMMAND" "$@"
fi

exec "$PROJECT_ROOT/scripts/env/with_flox.sh" bash -lc "$run_swift_ui_command" bash "$PROJECT_ROOT" "$SWIFT_PACKAGE_DIR" "$SWIFT_SUBCOMMAND" "$@"
