#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rm -rf "$PROJECT_ROOT/build"/*
rm -rf "$PROJECT_ROOT/volumes/cache"/*
rm -rf "$PROJECT_ROOT/volumes/logs"/*

mkdir -p \
  "$PROJECT_ROOT/build/python/cache/pip" \
  "$PROJECT_ROOT/build/python/cache/poetry" \
  "$PROJECT_ROOT/build/python/cache/uv" \
  "$PROJECT_ROOT/build/python/pycache" \
  "$PROJECT_ROOT/build/swift" \
  "$PROJECT_ROOT/build/artifacts" \
  "$PROJECT_ROOT/build/xdg/config" \
  "$PROJECT_ROOT/build/xdg/cache" \
  "$PROJECT_ROOT/build/xdg/data" \
  "$PROJECT_ROOT/build/xdg/state" \
  "$PROJECT_ROOT/build/home" \
  "$PROJECT_ROOT/volumes/cache/huggingface" \
  "$PROJECT_ROOT/volumes/cache/transformers" \
  "$PROJECT_ROOT/volumes/logs"

echo "Reset complete. Preserved volumes/models and deps links."
