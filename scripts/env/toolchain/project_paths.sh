#!/usr/bin/env bash

hybrid_ai_assert_under_project() {
  local p="$1"
  local project_root

  project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

  case "$p" in
    "$project_root"/*) ;;
    *)
      echo "ERROR: path outside project root: $p" >&2
      return 1
      ;;
  esac
}

# Create directories and assert each is under the project root.
# Guards against path-construction bugs that could silently write outside the
# project tree (e.g. a variable expanding to an absolute host path).
hybrid_ai_ensure_dirs_under_project() {
  local dir
  mkdir -p "$@"
  for dir in "$@"; do
    hybrid_ai_assert_under_project "$dir"
  done
}
