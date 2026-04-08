#!/usr/bin/env bash

set -euo pipefail

# inputs from Bazel
PYPROJECT_TOML="{{pyproject_toml}}"
REQUIREMENTS_TXT="{{requirements_txt}}"
COMPILE_COMMAND="{{compile_command}}"
UV_LOCK="{{uv_lock}}"

WORK_DIR="$PWD/.uv_export_workdir"
trap 'rm -rf "$WORK_DIR"' EXIT
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

INPUT_FILES=(
{{input_files}}
)

# Recreate a temporary workspace with the same directory structure as the original, and copy all input
# files there in order to generate uv.lock that doesn't overwrite the original one
for file in "${INPUT_FILES[@]}"; do
    dst="$WORK_DIR/$file"
    mkdir -p "$(dirname "$dst")"
    cp "$file" "$dst"
done

PROJECT_DIR="$WORK_DIR/$(dirname "$PYPROJECT_TOML")"
LOCK_FILE="$PROJECT_DIR/uv.lock"

# Check if lockfile is up to date (non-empty and valid for current pyproject.toml)
if [ ! -s "$LOCK_FILE" ] || ! {{uv}} lock --project "$PROJECT_DIR" --locked {{lock_args}} >/dev/null 2>&1; then
    # If lockfile exists but is empty, remove it so uv lock starts fresh
    if [ -f "$LOCK_FILE" ] && [ ! -s "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE"
    fi

    {{uv}} lock --project "$PROJECT_DIR" {{lock_args}}
fi

{{uv}} export \
    {{export_args}} \
    --project="$PROJECT_DIR" \
    --output-file="$REQUIREMENTS_TXT" \
    "$@"

cp "$LOCK_FILE" "$UV_LOCK"
