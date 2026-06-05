#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export -n PROJECT_ROOT 2>/dev/null || true

hybrid_ai_assert_under_project() {
  local p="$1"
  case "$p" in
    "$PROJECT_ROOT"/*) ;;
    *)
      echo "ERROR: path outside project root: $p" >&2
      return 1
      ;;
  esac
}
