#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"
source "$project_root/scripts/env/toolchain/common.sh"
source "$project_root/scripts/env/toolchain/nix/nix_setup.sh"

FSTAB_PATH="${FSTAB_PATH:-/etc/fstab}"
FSTAB_ENTRY="$NIX_ISOLATED_ROOT $NIX_MOUNT_POINT none bind 0 0"

usage() {
  cat <<EOF
Usage: $(basename "$0") <status|print|install|remove>

Commands:
  status   Show whether the canonical bind-mount entry exists in $FSTAB_PATH.
  print    Print the canonical bind-mount entry.
  install  Append the canonical bind-mount entry to $FSTAB_PATH.
  remove   Remove the canonical bind-mount entry from $FSTAB_PATH.

Safety:
  install requires CONFIRM_WRITE_FSTAB=YES
  remove requires CONFIRM_REMOVE_FSTAB=YES
EOF
}

find_mountpoint_entries() {
  awk -v mountpoint="$NIX_MOUNT_POINT" '
    $0 !~ /^[[:space:]]*#/ && NF >= 2 && $2 == mountpoint { print }
  ' "$FSTAB_PATH"
}

has_exact_entry() {
  grep -Fqx "$FSTAB_ENTRY" "$FSTAB_PATH"
}

backup_fstab() {
  local backup_path
  backup_path="${FSTAB_PATH}.hybrid-ai.$(date +%Y%m%d%H%M%S).bak"
  run_as_root cp "$FSTAB_PATH" "$backup_path"
  echo "Backup written to: $backup_path"
}

status_entry() {
  local entries
  entries="$(find_mountpoint_entries || true)"

  if has_exact_entry; then
    echo "status=present entry=$FSTAB_ENTRY"
    return
  fi

  if [[ -n "$entries" ]]; then
    echo "status=conflict mountpoint=$NIX_MOUNT_POINT"
    printf '%s\n' "$entries"
    return
  fi

  echo "status=absent entry=$FSTAB_ENTRY"
}

install_entry() {
  if [[ "${CONFIRM_WRITE_FSTAB:-}" != "YES" ]]; then
    echo "Refusing to modify $FSTAB_PATH without explicit confirmation." >&2
    echo "Re-run with: CONFIRM_WRITE_FSTAB=YES scripts/env/toolchain/nix/nix_fstab_manage.sh install" >&2
    exit 1
  fi

  if has_exact_entry; then
    echo "OK: canonical bind-mount entry already present in $FSTAB_PATH"
    return
  fi

  local entries
  entries="$(find_mountpoint_entries || true)"
  if [[ -n "$entries" ]]; then
    echo "ERROR: found conflicting $NIX_MOUNT_POINT entries in $FSTAB_PATH:" >&2
    printf '%s\n' "$entries" >&2
    exit 1
  fi

  backup_fstab
  run_as_root sh -c "printf '%s\n' '$FSTAB_ENTRY' >> '$FSTAB_PATH'"
  echo "Added entry to $FSTAB_PATH"
}

remove_entry() {
  if [[ "${CONFIRM_REMOVE_FSTAB:-}" != "YES" ]]; then
    echo "Refusing to modify $FSTAB_PATH without explicit confirmation." >&2
    echo "Re-run with: CONFIRM_REMOVE_FSTAB=YES scripts/env/toolchain/nix/nix_fstab_manage.sh remove" >&2
    exit 1
  fi

  if ! has_exact_entry; then
    echo "No exact hybrid-ai bind-mount entry found in $FSTAB_PATH"
    return
  fi

  backup_fstab
  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' EXIT
  awk -v entry="$FSTAB_ENTRY" '$0 != entry { print }' "$FSTAB_PATH" > "$tmp_file"
  run_as_root install -m 0644 "$tmp_file" "$FSTAB_PATH"
  echo "Removed entry from $FSTAB_PATH"
}

case "${1:-}" in
  status)
    status_entry
    ;;
  print)
    printf '%s\n' "$FSTAB_ENTRY"
    ;;
  install)
    install_entry
    ;;
  remove)
    remove_entry
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac