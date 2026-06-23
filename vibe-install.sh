#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/dev}"
export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${HOME}/.opencode/bin:${PATH}"
export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-${HOME}/.local}"

have() {
    command -v "$1" >/dev/null 2>&1
}

if ! have node || ! have npm; then
    mise install node@lts
    mise use -g node@lts
fi

npm config set prefix "${NPM_CONFIG_PREFIX}"

npm_packages=()
have paseo || npm_packages+=("@getpaseo/cli")
have claude || npm_packages+=("@anthropic-ai/claude-code")
have codex || npm_packages+=("@openai/codex")
have copilot || npm_packages+=("@github/copilot")
have pi || npm_packages+=("@earendil-works/pi-coding-agent")
have serve || npm_packages+=("serve")
if [ "${#npm_packages[@]}" -gt 0 ]; then
    npm install -g "${npm_packages[@]}"
fi

if ! have opencode; then
    curl -fsSL https://opencode.ai/install | bash
fi

if ! have vibe || ! have vibe-acp; then
    curl -LsSf https://mistral.ai/vibe/install.sh | bash
fi
