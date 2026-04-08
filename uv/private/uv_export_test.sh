#!/usr/bin/env bash

set -euo pipefail

GENERATED_REQUIREMENTS_TXT="{{generated_requirements_txt}}"
GENERATED_UV_LOCK="{{generated_uv_lock}}"
REQUIREMENTS_TXT="{{requirements_txt_workspace_path}}"
UV_LOCK="{{uv_lock_workspace_path}}"
COMPILE_COMMAND="{{compile_command}}"

if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
  REQUIREMENTS_TXT="$BUILD_WORKSPACE_DIRECTORY/$REQUIREMENTS_TXT"
  UV_LOCK="$BUILD_WORKSPACE_DIRECTORY/$UV_LOCK"
fi

if [ ! -f "$REQUIREMENTS_TXT" ]; then
  echo >&2 "FAIL: $REQUIREMENTS_TXT is missing. Run '$COMPILE_COMMAND' to update."
  exit 1
fi

if ! diff -u "$REQUIREMENTS_TXT" "$GENERATED_REQUIREMENTS_TXT"; then
  echo >&2 "FAIL: $REQUIREMENTS_TXT is out-of-date. Run '$COMPILE_COMMAND' to update."
  exit 1
fi

if [ ! -f "$UV_LOCK" ]; then
  echo >&2 "FAIL: $UV_LOCK is missing. Run '$COMPILE_COMMAND' to update."
  exit 1
fi

if ! diff -u "$UV_LOCK" "$GENERATED_UV_LOCK"; then
  echo >&2 "FAIL: $UV_LOCK is out-of-date. Run '$COMPILE_COMMAND' to update."
  exit 1
fi
