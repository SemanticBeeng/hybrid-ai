#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
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
source "$PROJECT_ROOT/scripts/env/toolchain/swift/swift_env.sh"
hybrid_ai_activate_swift_env
export HYBRID_AI_ENABLE_GTK_UI=1

gtk_modules=(gtk4 libadwaita-1)

if ! command -v pkg-config >/dev/null 2>&1; then
  echo "ERROR: pkg-config is required for the GTK/libadwaita Swift UI workflow." >&2
  exit 1
fi

if ! pkg-config --exists "${gtk_modules[@]}"; then
  echo "ERROR: missing pkg-config modules: ${gtk_modules[*]}" >&2
  echo "Install GTK/libadwaita through env/swift/manifest.toml and re-sync Flox." >&2
  exit 1
fi

swiftpm_flags=()
for flag in $(pkg-config --cflags "${gtk_modules[@]}"); do
  swiftpm_flags+=("-Xcc" "$flag")
done
for flag in $(pkg-config --libs "${gtk_modules[@]}"); do
  swiftpm_flags+=("-Xlinker" "$flag")
done

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

  source "$PROJECT_ROOT/scripts/env/toolchain/swift/gtk_ui_runtime.sh"
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

if [[ -n "${FLOX_ENV:-}" && "${FLOX_ENV_PROJECT:-}" == "$PROJECT_ROOT" ]]; then
  exec bash -lc "$run_swift_ui_command" bash "$PROJECT_ROOT" "$SWIFT_PACKAGE_DIR" "$SWIFT_SUBCOMMAND" "$@"
fi

exec "$PROJECT_ROOT/scripts/env/toolchain/nix/flox_with.sh" bash -lc "$run_swift_ui_command" bash "$PROJECT_ROOT" "$SWIFT_PACKAGE_DIR" "$SWIFT_SUBCOMMAND" "$@"
