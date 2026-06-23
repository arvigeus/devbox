#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/dev
export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${HOME}/.opencode/bin:${PATH}"
export NPM_CONFIG_PREFIX="${HOME}/.local"
export PASEO_LISTEN=0.0.0.0:6767
export T3CODE_BASE_DIR="${T3CODE_BASE_DIR:-${HOME}/.local/share/t3code}"
opencode_server_username="${OPENCODE_SERVER_USERNAME:-}"
opencode_server_password="${OPENCODE_SERVER_PASSWORD:-}"

# OpenCode's server auth env is global. If left in the daemon environment,
# Paseo/T3 Code's private helper servers inherit it and their SDK clients get
# 401s from random localhost ports. Keep it only for the public web process.
unset OPENCODE_SERVER_USERNAME OPENCODE_SERVER_PASSWORD

/usr/local/bin/vibe-install

# "Warm-up" Azure CLI to help discoverability
timeout 15 az --version >/dev/null 2>&1 || true

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    # shellcheck disable=SC2016
    /usr/local/bin/json update "${HOME}/.local/share/opencode/auth.json" \
        --arg key "${OPENROUTER_API_KEY}" \
        '.openrouter = {"type": "api", "key": $key}' \
        || true
fi

mkdir -p "${T3CODE_BASE_DIR}"
(
    cd /opt/t3code
    T3CODE_TELEMETRY_ENABLED=false exec node dist/bin.mjs serve \
        --host 0.0.0.0 \
        --port 3773 \
        --base-dir "${T3CODE_BASE_DIR}" \
        /workspace
) &

if [ -n "${opencode_server_password}" ]; then
    OPENCODE_SERVER_USERNAME="${opencode_server_username}" \
        OPENCODE_SERVER_PASSWORD="${opencode_server_password}" \
        opencode web --hostname 0.0.0.0 --port 4096 &
fi

serve -s /opt/paseo-web -l tcp://0.0.0.0:6768 &

if [ "${AUTO_UPDATE:-true}" = "true" ]; then
    # Re-run every 24 h while the container is running.
    # Sleep comes first so startup and the first scheduled run don't overlap.
    ( while sleep 86400; do /usr/local/bin/vibe-update; done ) &
fi

exec "$@"
