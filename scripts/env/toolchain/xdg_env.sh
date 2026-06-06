#!/usr/bin/env bash

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if ! declare -F hybrid_ai_assert_under_project >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/project_paths.sh"
fi

export XDG_CONFIG_HOME="$project_root/build/xdg/config"
export XDG_CACHE_HOME="$project_root/build/xdg/cache"
export XDG_DATA_HOME="$project_root/build/xdg/data"
export XDG_STATE_HOME="$project_root/build/xdg/state"

# Use an isolated HOME for tools that hardcode HOME lookups.
export HOME="$project_root/build/home"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$HOME"

hybrid_ai_assert_under_project "$XDG_CONFIG_HOME"
hybrid_ai_assert_under_project "$XDG_CACHE_HOME"
hybrid_ai_assert_under_project "$XDG_DATA_HOME"
hybrid_ai_assert_under_project "$XDG_STATE_HOME"
hybrid_ai_assert_under_project "$HOME"
