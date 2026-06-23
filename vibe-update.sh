#!/usr/bin/env bash
set -euo pipefail

echo "[update] $(date '+%Y-%m-%d %H:%M:%S')"

run() {
    command -v "$1" >/dev/null 2>&1 || return 0
    "$@" 2>/dev/null || true
}

run mise self-update --yes

run npm update -g

run copilot update

run opencode upgrade

run uv tool upgrade mistral-vibe

echo "[update] done."
