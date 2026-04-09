rules_uv_hash_file() {
    sha256sum "$1" | cut -d ' ' -f1
}

rules_uv_hash_text() {
    printf '%s' "$1" | sha256sum | cut -d ' ' -f1
}

rules_uv_cache_prepare() {
    local requirements_txt="$1"
    local runner_path="$2"
    local runner_dir
    local cache_id

    RULES_UV_OUTPUT_FILE="$requirements_txt"
    if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
        RULES_UV_OUTPUT_FILE="$BUILD_WORKSPACE_DIRECTORY/$requirements_txt"
    fi

    runner_dir="$(cd "$(dirname "$runner_path")" && pwd -P)"
    cache_id="$(rules_uv_hash_text "${RULES_UV_CACHE_RULE}|${RULES_UV_OUTPUT_FILE}|${runner_dir}")"
    RULES_UV_CACHE_FILE="${runner_dir}/.rules_uv_cache/${cache_id}.cache"
}

rules_uv_compute_cache_key() {
    local payload
    local arg
    local file_path

    payload="rule=${RULES_UV_CACHE_RULE}"$'\n'
    payload+="static_args_start"$'\n'"${RULES_UV_CACHE_STATIC_ARGS}"$'\n'"static_args_end"$'\n'
    payload+="env_start"$'\n'"${RULES_UV_CACHE_ENV}"$'\n'"env_end"$'\n'

    for arg in "$@"; do
        payload+="runtime_arg=$arg"$'\n'
    done

    while IFS= read -r file_path; do
        if [ -z "$file_path" ]; then
            continue
        fi
        if [ ! -f "$file_path" ]; then
            echo >&2 "Error: tracked input file '$file_path' does not exist."
            exit 1
        fi
        payload+="input=$file_path:$(rules_uv_hash_file "$file_path")"$'\n'
    done <<< "${RULES_UV_CACHE_INPUTS}"

    rules_uv_hash_text "$payload"
}

rules_uv_cache_hit() {
    local cache_key
    local cached_key

    cache_key="$(rules_uv_compute_cache_key "$@")"
    if [ -f "$RULES_UV_CACHE_FILE" ] && [ -f "$RULES_UV_OUTPUT_FILE" ]; then
        cached_key="$(cat "$RULES_UV_CACHE_FILE")"
        [ "$cached_key" = "$cache_key" ]
        return
    fi

    return 1
}

rules_uv_cache_write() {
    local updated_cache_key

    mkdir -p "$(dirname "$RULES_UV_CACHE_FILE")"
    updated_cache_key="$(rules_uv_compute_cache_key "$@")"
    printf '%s\n' "$updated_cache_key" > "$RULES_UV_CACHE_FILE"
}
