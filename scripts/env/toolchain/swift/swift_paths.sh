#!/usr/bin/env bash

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

if ! declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/project_paths.sh"
fi

export SWIFT_BUILD_PATH="$project_root/build/swift"
export CLANG_MODULE_CACHE_PATH="$project_root/build/swift/clang-module-cache"
export SWIFTPM_PACKAGECACHE="$project_root/build/swift/package-cache"

mkdir -p "$SWIFT_BUILD_PATH" "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_PACKAGECACHE"

hybrid_ai_assert_under_project "$SWIFT_BUILD_PATH"
hybrid_ai_assert_under_project "$CLANG_MODULE_CACHE_PATH"
hybrid_ai_assert_under_project "$SWIFTPM_PACKAGECACHE"
