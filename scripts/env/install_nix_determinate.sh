#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/common.sh"

NIX_PORTABLE_URL="${NIX_PORTABLE_URL:-https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable}"
TARGET_BIN_DIR="$NIX_ISOLATED_ROOT/bin"
TARGET_NIX_BIN="$TARGET_BIN_DIR/nix"

case "$NIX_ISOLATED_ROOT" in
  /nix|/nix/*)
    echo "ERROR: refusing to install/configure nix with root /nix target: $NIX_ISOLATED_ROOT" >&2
    exit 1
    ;;
esac

if [[ "$NIX_ISOLATED_ROOT" == "/opt/bin/dev/nix" ]]; then
  echo "INFO: using allowed non-/nix isolated root: $NIX_ISOLATED_ROOT"
fi

if [[ -d "/nix" ]]; then
  echo "ERROR: root /nix already exists on this host." >&2
  echo "Run: CONFIRM_REMOVE_ROOT_NIX=YES scripts/env/remove_root_nix.sh" >&2
  exit 1
fi

mkdir -p "$TARGET_BIN_DIR" "$NIX_ISOLATED_ROOT/etc/nix" "$NIX_ISOLATED_ROOT/var/nix"

if [[ ! -w "$TARGET_BIN_DIR" ]]; then
  echo "ERROR: no write permission to $TARGET_BIN_DIR" >&2
  echo "Grant write access or choose another non-/nix path via NIX_ISOLATED_ROOT." >&2
  exit 1
fi

if [[ -x "$TARGET_NIX_BIN" ]]; then
  echo "nix already installed at $TARGET_NIX_BIN"
else
  arch="$(uname -m)"
  case "$arch" in
    x86_64) nix_portable_arch="x86_64" ;;
    aarch64|arm64) nix_portable_arch="aarch64" ;;
    *)
      echo "ERROR: unsupported architecture for nix-portable: $arch" >&2
      exit 1
      ;;
  esac

  if [[ "$NIX_PORTABLE_URL" == "https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable" ]]; then
    NIX_PORTABLE_URL="https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-$nix_portable_arch"
  fi

  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' EXIT
  echo "Downloading nix-portable from: $NIX_PORTABLE_URL"
  curl -fsSL "$NIX_PORTABLE_URL" -o "$tmp_file"
  install -m 0755 "$tmp_file" "$TARGET_NIX_BIN"
fi

cat >"$NIX_ISOLATED_ROOT/etc/nix/nix.conf" <<EOF
experimental-features = nix-command flakes
accept-flake-config = true
EOF

"$TARGET_NIX_BIN" --version

cat <<EOF
Nix installed in non-root isolated location.
Configured path $NIX_ISOLATED_ROOT is valid as long as it is not under /nix.
Policy-compliant path: $NIX_ISOLATED_ROOT
Nix binary: $TARGET_NIX_BIN
EOF
