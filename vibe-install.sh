#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/dev}"
export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${HOME}/.opencode/bin:${PATH}"
export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-${HOME}/.local}"

# DEVBOX_AI_TOOLS:
#   all                  default
#   none
#   claude,codex,grok    comma-separated tool names

have() {
    command -v "$1" >/dev/null 2>&1
}

enabled() {
    local tool="$1"
    local requested="${DEVBOX_AI_TOOLS:-all}"
    local item

    case "$requested" in
        all) return 0 ;;
        none) return 1 ;;
    esac

    for item in ${requested//,/ }; do
        [[ "$item" == "$tool" ]] && return 0
    done

    return 1
}

ensure_node() {
    if ! have node || ! have npm; then
        mise install node@lts
        mise use -g node@lts
    fi

    npm config set prefix "$NPM_CONFIG_PREFIX"
}

reconcile_paseo() {
    have paseo || npm install -g "@getpaseo/cli"
}

reconcile_opencode() {
    # if enabled opencode; then
        have opencode || curl -fsSL https://opencode.ai/install | bash
    # elif have opencode; then
    #     rm -f \
    #         "$HOME/.opencode/bin/opencode" \
    #         "$HOME/.local/bin/opencode"

    #     rmdir "$HOME/.opencode/bin" "$HOME/.opencode" 2>/dev/null || true
    # fi
}

reconcile_serve() {
    have serve || npm install -g serve
}

reconcile_claude() {
    if enabled claude; then
        have claude || npm install -g "@anthropic-ai/claude-code"
    else
        have claude && npm uninstall -g "@anthropic-ai/claude-code" || true
    fi
}

reconcile_codex() {
    if enabled codex; then
        have codex || npm install -g "@openai/codex"
    else
        have codex && npm uninstall -g "@openai/codex" || true
    fi
}

reconcile_copilot() {
    if enabled copilot; then
        have copilot || npm install -g "@github/copilot"
    else
        have copilot && npm uninstall -g "@github/copilot" || true
    fi
}

reconcile_grok() {
    if enabled grok; then
        have grok || npm install -g "@xai-official/grok"
    else
        have grok && npm uninstall -g "@xai-official/grok" || true
    fi
}

reconcile_pi() {
    if enabled pi; then
        have pi || npm install -g "@earendil-works/pi-coding-agent"
        have pi-mcp-adapter || npm install -g "pi-mcp-adapter"
    else
        have pi && npm uninstall -g "@earendil-works/pi-coding-agent" || true
        have pi-mcp-adapter && npm uninstall -g "pi-mcp-adapter" || true
    fi
}

reconcile_vibe() {
    if enabled vibe; then
        { have vibe && have vibe-acp; } || curl -LsSf https://mistral.ai/vibe/install.sh | bash
    elif have vibe || have vibe-acp; then
        have uv && uv tool uninstall mistral-vibe 2>/dev/null || true

        rm -f \
            "$HOME/.local/bin/vibe" \
            "$HOME/.local/bin/vibe-acp"
    fi
}

main() {
    ensure_node

    reconcile_paseo
    reconcile_opencode
    reconcile_serve

    reconcile_claude
    reconcile_codex
    reconcile_copilot
    reconcile_grok
    reconcile_pi
    reconcile_vibe
}

main "$@"