#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

# shellcheck disable=SC1090
source "$project_root/scripts/env/toolchain/project_paths.sh"

DRY_RUN=0
INCLUDE_LOGS=0
RM_BIN="${RM_BIN:-/usr/bin/rm}"
FIND_BIN="${FIND_BIN:-/usr/bin/find}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--include-logs]

Remove project-local generated caches and transient toolchain state.

By default this preserves:
  - env/*/manifest.toml source manifests
  - volumes/models
  - deps/libs and deps/models
  - volumes/logs

Options:
  --dry-run       Print what would be removed without deleting anything.
  --include-logs  Also remove volumes/logs contents.
  -h, --help      Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --include-logs)
      INCLUDE_LOGS=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$DRY_RUN" -eq 0 && -n "${FLOX_ENV:-}" && ( "$FLOX_ENV" == "$project_root"/.flox/run/* || "$FLOX_ENV" == "$project_root"/env/*/.flox/run/* ) ]]; then
  echo "ERROR: refusing to remove project Flox runtime state from inside an active project Flox environment." >&2
  echo "Re-run from a clean shell, for example:" >&2
  echo "  env -u FLOX_ENV -u FLOX_ENV_CACHE $0" >&2
  exit 1
fi

remove_path() {
  local path="$1"

  hybrid_ai_assert_under_project "$path"

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'would remove: %s\n' "$path"
    return
  fi

  "$RM_BIN" -rf -- "$path"
  printf 'removed: %s\n' "$path"
}

remove_children() {
  local dir="$1"

  hybrid_ai_assert_under_project "$dir"

  if [[ ! -d "$dir" ]]; then
    return
  fi

  local child
  shopt -s dotglob nullglob
  for child in "$dir"/*; do
    if [[ "${child##*/}" == ".gitkeep" ]]; then
      continue
    fi

    remove_path "$child"
  done
  shopt -u dotglob nullglob
}

# Canonical project-local cache/build roots from common.sh concern modules.
remove_children "$project_root/build"
remove_children "$project_root/volumes/cache"

# Flox generated state is project-local and safe to regenerate from manifest.toml.
if [[ -d "$project_root/.flox" ]]; then
  remove_path "$project_root/.flox/cache"
  remove_path "$project_root/.flox/run"
  remove_path "$project_root/.flox/env/manifest.lock"
fi

for flox_dir in "$project_root"/env/*/.flox; do
  [[ -d "$flox_dir" ]] || continue
  remove_path "$flox_dir/cache"
  remove_path "$flox_dir/run"
  remove_path "$flox_dir/env/manifest.lock"
done

# Source-adjacent byproducts that should never be used by this project layout.
remove_path "$project_root/src/swift/.build"

while IFS= read -r -d '' cache_dir; do
  remove_path "$cache_dir"
done < <("$FIND_BIN" "$project_root/src" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -print0 2>/dev/null || true)

if [[ "$INCLUDE_LOGS" -eq 1 ]]; then
  remove_children "$project_root/volumes/logs"
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  # common.sh sources the concern-specific modules that own cache directory
  # creation: xdg_env.sh, swift_paths.sh, and inference_env.sh.
  hash -r
  # shellcheck disable=SC1090
  source "$project_root/scripts/env/toolchain/common.sh"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete. No files were removed."
else
  echo "Project caches cleaned."
fi
