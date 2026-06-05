#!/usr/bin/env bash

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

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
