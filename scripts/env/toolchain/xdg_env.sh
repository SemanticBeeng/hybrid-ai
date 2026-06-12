#!/usr/bin/env bash

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

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

hybrid_ai_ensure_dirs_under_project "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$HOME"
