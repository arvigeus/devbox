#!/usr/bin/env bash
set -euo pipefail

echo "[update] $(date '+%Y-%m-%d %H:%M:%S')"

have() {
    command -v "$1" >/dev/null 2>&1
}

run() {
    "$@" 2>/dev/null || true
}

have mise && run mise self-update --yes

have npm && {
    run npm update -g
    run npm cache clean --force
}

have copilot && run copilot update

have opencode && run opencode upgrade

have uv && {
    run uv tool upgrade --all
    run uv cache prune
}

echo "[update] done."