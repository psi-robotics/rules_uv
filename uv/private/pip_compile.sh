#!/usr/bin/env bash

set -euo pipefail

# inputs from Bazel
REQUIREMENTS_IN="{{requirements_in}}"
REQUIREMENTS_TXT="{{requirements_txt}}"
CACHE_INPUTS=$(cat <<'__RULES_UV_CACHE_INPUTS__'
{{cache_inputs}}
__RULES_UV_CACHE_INPUTS__
)
CACHE_STATIC_ARGS=$(cat <<'__RULES_UV_CACHE_STATIC_ARGS__'
{{cache_static_args}}
__RULES_UV_CACHE_STATIC_ARGS__
)
CACHE_ENV=$(cat <<'__RULES_UV_CACHE_ENV__'
{{cache_env}}
__RULES_UV_CACHE_ENV__
)
source "{{cache_lib}}"

RULES_UV_CACHE_RULE="pip_compile"
RULES_UV_CACHE_INPUTS="$CACHE_INPUTS"
RULES_UV_CACHE_STATIC_ARGS="$CACHE_STATIC_ARGS"
RULES_UV_CACHE_ENV="$CACHE_ENV"
rules_uv_cache_prepare "$REQUIREMENTS_TXT" "$0"

if rules_uv_cache_hit "$@"; then
    echo "INFO: Inputs for $REQUIREMENTS_TXT are unchanged; skipping uv pip compile."
    exit 0
fi

{{uv}} pip compile \
    {{args}} \
    --output-file="$RULES_UV_OUTPUT_FILE" \
    "$REQUIREMENTS_IN" \
    "$@"

rules_uv_cache_write "$@"
