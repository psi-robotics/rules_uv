#!/usr/bin/env bash

set -euo pipefail

if [ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
  echo >&2 "FAIL: BUILD_WORKSPACE_DIRECTORY is not set. Run this target with 'bazel run'."
  exit 1
fi

GENERATED_REQUIREMENTS_TXT="{{generated_requirements_txt}}"
GENERATED_UV_LOCK="{{generated_uv_lock}}"
REQUIREMENTS_TXT="$BUILD_WORKSPACE_DIRECTORY/{{requirements_txt_workspace_path}}"
UV_LOCK="$BUILD_WORKSPACE_DIRECTORY/{{uv_lock_workspace_path}}"

mkdir -p "$(dirname "$REQUIREMENTS_TXT")"
mkdir -p "$(dirname "$UV_LOCK")"
cp "$GENERATED_REQUIREMENTS_TXT" "$REQUIREMENTS_TXT"
cp "$GENERATED_UV_LOCK" "$UV_LOCK"
