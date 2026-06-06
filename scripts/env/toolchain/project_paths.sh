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
