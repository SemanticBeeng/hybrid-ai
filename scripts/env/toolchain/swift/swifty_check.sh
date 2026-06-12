#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/common.sh"
source "$project_root/scripts/env/toolchain/swift/swift_env.sh"

hybrid_ai_activate_swift_env

printf "SWIFTLY_ROOT=%s\n" "$SWIFTLY_ROOT"
printf "SWIFTLY_HOME_DIR=%s\n" "$SWIFTLY_HOME_DIR"
printf "SWIFTLY_BIN_DIR=%s\n" "$SWIFTLY_BIN_DIR"
printf "swiftly_bin=%s\n" "$(command -v swiftly)"
printf "swift_bin=%s\n" "$(command -v swift)"
printf "swiftc_bin=%s\n" "$(command -v swiftc)"
printf "clang_bin=%s\n" "$(command -v clang || true)"
printf "sourcekit_lsp_bin=%s\n" "$(command -v sourcekit-lsp || true)"
printf "lldb_bin=%s\n" "$(command -v lldb || true)"
hybrid_ai_swift_version_line
swift package --version
hybrid_ai_assert_swift_version