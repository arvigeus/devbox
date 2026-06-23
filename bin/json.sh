#!/usr/bin/env bash
set -euo pipefail

json_update_file() {
    local json_target_file json_target_dir json_target_name json_tmp_file

    json_target_file="$1"
    shift

    json_target_dir="$(dirname "${json_target_file}")"
    json_target_name="$(basename "${json_target_file}")"

    mkdir -p "${json_target_dir}"
    json_tmp_file="$(mktemp "${json_target_dir}/.${json_target_name}.XXXXXX")"

    if [ -s "${json_target_file}" ]; then
        if ! jq "$@" "${json_target_file}" >"${json_tmp_file}"; then
            echo "JSON file is not valid; leaving ${json_target_file} unchanged." >&2
            rm -f "${json_tmp_file}"
            return 1
        fi
    elif ! jq -n "$@" >"${json_tmp_file}"; then
        rm -f "${json_tmp_file}"
        return 1
    fi

    mv "${json_tmp_file}" "${json_target_file}"
    chmod 600 "${json_target_file}"
}

case "${1:-}" in
    update)
        shift
        if [ "$#" -lt 2 ]; then
            echo "Usage: json update <file> <jq-args...>" >&2
            exit 2
        fi
        json_update_file "$@"
        ;;
    *)
        echo "Usage: json update <file> <jq-args...>" >&2
        exit 2
        ;;
esac
