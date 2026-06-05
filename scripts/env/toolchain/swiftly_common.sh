#!/usr/bin/env bash

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi

hybrid_ai_swiftly_configure() {
  export SWIFTLY_ROOT="${SWIFTLY_ROOT:-/opt/bin/dev/swiftly}"
  export SWIFTLY_HOME_DIR="${SWIFTLY_HOME_DIR:-$SWIFTLY_ROOT/home}"
  export SWIFTLY_BIN_DIR="${SWIFTLY_BIN_DIR:-$SWIFTLY_ROOT/bin}"
  export SWIFTLY_TOOLCHAINS_DIR="${SWIFTLY_TOOLCHAINS_DIR:-$SWIFTLY_ROOT/toolchains}"
  export SWIFTLY_VERSION="${SWIFTLY_VERSION:-1.1.1}"
  export HYBRID_AI_SWIFT_VERSION="${HYBRID_AI_SWIFT_VERSION:-6.3.2}"

  if [[ ":$PATH:" != *":$SWIFTLY_BIN_DIR:"* ]]; then
    export PATH="$SWIFTLY_BIN_DIR:$PATH"
  fi
}

hybrid_ai_swiftly_arch() {
  case "$(uname -m)" in
    x86_64|aarch64) uname -m ;;
    *)
      echo "ERROR: unsupported Swiftly architecture: $(uname -m)" >&2
      return 1
      ;;
  esac
}

hybrid_ai_swiftly_archive() {
  local arch=""
  arch="$(hybrid_ai_swiftly_arch)"
  printf 'swiftly-%s-%s.tar.gz\n' "$SWIFTLY_VERSION" "$arch"
}

hybrid_ai_swiftly_url() {
  printf 'https://download.swift.org/swiftly/linux/%s\n' "$(hybrid_ai_swiftly_archive)"
}

hybrid_ai_require_swiftly_env() {
  if [[ ! -r "$SWIFTLY_HOME_DIR/env.sh" ]]; then
    echo "ERROR: Swiftly env file not found at $SWIFTLY_HOME_DIR/env.sh" >&2
    echo "Run scripts/env/toolchain/swiftly_install.sh first." >&2
    return 1
  fi
}

hybrid_ai_source_swiftly_env() {
  hybrid_ai_require_swiftly_env
  # shellcheck disable=SC1090
  source "$SWIFTLY_HOME_DIR/env.sh"
  export SWIFTLY_HOME_DIR="$SWIFTLY_ROOT/home"
  export SWIFTLY_BIN_DIR="$SWIFTLY_ROOT/bin"
  export SWIFTLY_TOOLCHAINS_DIR="$SWIFTLY_ROOT/toolchains"
  hash -r
}

hybrid_ai_swift_version_line() {
  swift --version 2>/dev/null | head -n 1
}

hybrid_ai_swift_version_matches() {
  hybrid_ai_swift_version_line | grep -q "Swift version $HYBRID_AI_SWIFT_VERSION"
}

hybrid_ai_assert_swift_version() {
  if ! hybrid_ai_swift_version_matches; then
    echo "ERROR: expected Swift $HYBRID_AI_SWIFT_VERSION." >&2
    return 1
  fi
}

hybrid_ai_swiftly_configure