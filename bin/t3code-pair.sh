#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  t3code-pair

Issue a T3 Code pairing link using the devbox runtime state.

Set T3CODE_BASE_URL to the public URL that reaches the T3 Code server.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

BASE_DIR="${T3CODE_BASE_DIR:-${HOME:-/home/dev}/.local/share/t3code}"

if [ "$#" -gt 0 ]; then
  echo "t3code-pair does not accept arguments. Set T3CODE_BASE_URL instead." >&2
  exit 64
fi

if [ -z "${T3CODE_BASE_URL:-}" ]; then
  echo "T3CODE_BASE_URL is required, for example: https://t3code.example.com" >&2
  exit 64
fi

cd /opt/t3code
exec node dist/bin.mjs auth pairing create \
  --base-dir "${BASE_DIR}" \
  --base-url "${T3CODE_BASE_URL}"
