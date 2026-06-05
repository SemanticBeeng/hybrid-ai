#!/usr/bin/env bash

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
fi

if ! declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$PROJECT_ROOT/scripts/env/toolchain/project_paths.sh"
fi

export SWIFT_BUILD_PATH="$PROJECT_ROOT/build/swift"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/build/swift/clang-module-cache"
export SWIFTPM_PACKAGECACHE="$PROJECT_ROOT/build/swift/package-cache"

mkdir -p "$SWIFT_BUILD_PATH" "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_PACKAGECACHE"

hybrid_ai_assert_under_project "$SWIFT_BUILD_PATH"
hybrid_ai_assert_under_project "$CLANG_MODULE_CACHE_PATH"
hybrid_ai_assert_under_project "$SWIFTPM_PACKAGECACHE"
