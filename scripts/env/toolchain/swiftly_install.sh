#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$PROJECT_ROOT/scripts/env/toolchain/common.sh"
source "$PROJECT_ROOT/scripts/env/toolchain/swiftly_common.sh"

SWIFTLY_ARCHIVE="$(hybrid_ai_swiftly_archive)"
SWIFTLY_URL="$(hybrid_ai_swiftly_url)"

run_as_root install -d -m 0755 "$SWIFTLY_ROOT" "$SWIFTLY_HOME_DIR" "$SWIFTLY_BIN_DIR" "$SWIFTLY_TOOLCHAINS_DIR"

if [[ "$(id -u)" -ne 0 ]]; then
  run_as_root chown -R "$(id -u):$(id -g)" "$SWIFTLY_ROOT"
fi

if [[ ! -x "$SWIFTLY_BIN_DIR/swiftly" ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  echo "Downloading Swiftly from: $SWIFTLY_URL"
  curl --proto '=https' --tlsv1.2 -fsSL "$SWIFTLY_URL" -o "$tmp_dir/$SWIFTLY_ARCHIVE"
  tar -xzf "$tmp_dir/$SWIFTLY_ARCHIVE" -C "$tmp_dir"

  swiftly_bin="$(find "$tmp_dir" -type f -name swiftly -perm -111 | head -n 1)"
  if [[ -z "$swiftly_bin" ]]; then
    echo "ERROR: Swiftly executable not found in archive." >&2
    exit 1
  fi

  install -m 0755 "$swiftly_bin" "$SWIFTLY_BIN_DIR/swiftly"
fi

if [[ ! -r "$SWIFTLY_HOME_DIR/env.sh" ]]; then
  export SWIFTLY_TOOLCHAINS_DIR
  "$SWIFTLY_BIN_DIR/swiftly" init --quiet-shell-followup
fi

if grep -q '/\.local/share/swiftly/toolchains' "$SWIFTLY_HOME_DIR/env.sh" 2>/dev/null; then
  sed -i "s|^export SWIFTLY_TOOLCHAINS_DIR=.*|export SWIFTLY_TOOLCHAINS_DIR=\"$SWIFTLY_TOOLCHAINS_DIR\"|" "$SWIFTLY_HOME_DIR/env.sh"
fi

hybrid_ai_source_swiftly_env

if ! hybrid_ai_swift_version_matches; then
  swiftly install --use "$HYBRID_AI_SWIFT_VERSION"
else
  swiftly use "$HYBRID_AI_SWIFT_VERSION" >/dev/null
fi

hash -r

cat <<EOF
Swiftly installation complete.
Swiftly root: $SWIFTLY_ROOT
SWIFTLY_HOME_DIR: $SWIFTLY_HOME_DIR
SWIFTLY_BIN_DIR: $SWIFTLY_BIN_DIR
SWIFTLY_TOOLCHAINS_DIR: $SWIFTLY_TOOLCHAINS_DIR
swift: $(command -v swift)
$(hybrid_ai_swift_version_line)
EOF
