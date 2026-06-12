#!/usr/bin/env bash
set -euo pipefail

project_root="${PROJECT_ROOT:?ERROR: PROJECT_ROOT not set. Source scripts/local_env.sh first.}"

rm -rf "$project_root/build"/*
rm -rf "$project_root/volumes/cache"/*
rm -rf "$project_root/volumes/logs"/*

mkdir -p \
  "$project_root/build/python/cache/pip" \
  "$project_root/build/python/cache/poetry" \
  "$project_root/build/python/cache/uv" \
  "$project_root/build/python/pycache" \
  "$project_root/build/swift" \
  "$project_root/build/artifacts" \
  "$project_root/build/xdg/config" \
  "$project_root/build/xdg/cache" \
  "$project_root/build/xdg/data" \
  "$project_root/build/xdg/state" \
  "$project_root/build/home" \
  "$project_root/volumes/cache/huggingface" \
  "$project_root/volumes/cache/transformers" \
  "$project_root/volumes/logs"

echo "Reset complete. Preserved volumes/models and deps links."
