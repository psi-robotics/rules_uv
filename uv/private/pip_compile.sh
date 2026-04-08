#!/usr/bin/env bash

set -euo pipefail

# inputs from Bazel
REQUIREMENTS_IN="{{requirements_in}}"
REQUIREMENTS_TXT="{{requirements_txt}}"

if [ -z "${UV_CACHE_DIR:-}" ]; then
    if [ -n "${XDG_CACHE_HOME:-}" ]; then
        UV_CACHE_DIR="$XDG_CACHE_HOME/uv"
    elif [ -n "${HOME:-}" ]; then
        UV_CACHE_DIR="$HOME/.cache/uv"
    else
        UV_CACHE_DIR="${TMPDIR:-/tmp}/rules_uv_uv_cache"
    fi
fi

if ! mkdir -p "$UV_CACHE_DIR" 2>/dev/null; then
    UV_CACHE_DIR="${TMPDIR:-/tmp}/rules_uv_uv_cache"
    mkdir -p "$UV_CACHE_DIR"
fi
export UV_CACHE_DIR

{{uv}} pip compile \
    {{args}} \
    --output-file="$REQUIREMENTS_TXT" \
    "$REQUIREMENTS_IN" \
    "$@"
