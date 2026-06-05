#!/usr/bin/env bash

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

  for flag in $(pkg-config --libs-only-L gtk4 libadwaita-1); do
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
