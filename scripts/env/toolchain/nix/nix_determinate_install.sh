#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"

DETERMINATE_INSTALLER_URL="${DETERMINATE_INSTALLER_URL:-https://install.determinate.systems/nix}"
TARGET_BIN_DIR="$NIX_ISOLATED_ROOT/bin"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: this installer script currently supports Linux only." >&2
  exit 1
fi

"$PROJECT_ROOT/scripts/env/toolchain/nix/nix_mount_manage.sh" mount
ensure_nix_bind_mount

run_as_root mkdir -p "$TARGET_BIN_DIR"

if [[ -x "$DETERMINATE_NIX_BIN" && -x "$DETERMINATE_NIX_INSTALLER_BIN" ]]; then
  echo "Determinate Nix already installed under $NIX_MOUNT_POINT"
else
  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' EXIT
  echo "Downloading Determinate Nix installer from: $DETERMINATE_INSTALLER_URL"
  curl --proto '=https' --tlsv1.2 -fsSL "$DETERMINATE_INSTALLER_URL" -o "$tmp_file"

  run_as_root sh "$tmp_file" install linux \
    --no-confirm \
    --no-modify-profile \
    --diagnostic-endpoint="" \
    --no-start-daemon
fi

tmp_nix_wrapper="$(mktemp)"
cat >"$tmp_nix_wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$DETERMINATE_NIX_BIN" "\$@"
EOF
run_as_root install -m 0755 "$tmp_nix_wrapper" "$NIX_WRAPPER_BIN"
rm -f "$tmp_nix_wrapper"

tmp_installer_wrapper="$(mktemp)"
cat >"$tmp_installer_wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$DETERMINATE_NIX_INSTALLER_BIN" "\$@"
EOF
run_as_root install -m 0755 "$tmp_installer_wrapper" "$NIX_INSTALLER_WRAPPER_BIN"
rm -f "$tmp_installer_wrapper"

run_as_root "$NIX_WRAPPER_BIN" --version

cat <<EOF
Determinate Nix installation complete.
Logical root: $NIX_MOUNT_POINT
Physical backing root: $NIX_ISOLATED_ROOT
Nix wrapper: $NIX_WRAPPER_BIN
Installer wrapper: $NIX_INSTALLER_WRAPPER_BIN
Host prerequisite: the Determinate Nix runtime must provide $NIX_DAEMON_SOCKET before normal-user Flox/Nix commands run.
Project scripts validate that socket but do not start host Nix services automatically.
Start the daemon manually if needed:
  sudo /nix/var/nix/profiles/default/bin/nix-daemon
EOF
