#!/usr/bin/env bash

set -euo pipefail

GENERATED_REQUIREMENTS_TXT="{{compiled_requirements_txt}}"
REQUIREMENTS_TXT="{{requirements_txt_workspace_path}}"
COMPILE_COMMAND="{{compile_command}}"

if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
  REQUIREMENTS_TXT="$BUILD_WORKSPACE_DIRECTORY/$REQUIREMENTS_TXT"
fi

if [ ! -f "$REQUIREMENTS_TXT" ]; then
  echo >&2 "FAIL: $REQUIREMENTS_TXT is missing. Run '$COMPILE_COMMAND' to update."
  exit 1
fi

if ! diff -u "$REQUIREMENTS_TXT" "$GENERATED_REQUIREMENTS_TXT"; then
  echo >&2 "FAIL: $REQUIREMENTS_TXT is out-of-date. Run '$COMPILE_COMMAND' to update."
  exit 1
fi
