image := "arvigeus/devbox"
dev_image := "devbox"

default:
	@just --list

# Build the image from the official package source.
build image_version="":
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"
	PLATFORM="${PLATFORM:-linux/amd64}"
	IMAGE_VERSION="{{image_version}}"
	TAGS=(-t "{{dev_image}}" -t "{{image}}:latest")

	if [ -n "${IMAGE_VERSION}" ]; then
	  TAGS+=(-t "{{image}}:${IMAGE_VERSION}")
	fi

	"${DOCKER}" build \
	  --progress=plain \
	  --platform "${PLATFORM}" \
	  --file Dockerfile \
	  "${TAGS[@]}" \
	  .

# Build the local dev image and start docker compose.
dev:
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"
	DATA_DIR="${DATA:-./data}"
	WORKSPACE_DIR="${HOST_WORKSPACE:-./data/workspace}"

	just build

	mkdir -p "${DATA_DIR}/devbox/home" "${WORKSPACE_DIR}"

	if "${DOCKER}" compose version >/dev/null 2>&1; then
	  COMPOSE=("${DOCKER}" compose)
	elif command -v docker-compose >/dev/null 2>&1; then
	  COMPOSE=(docker-compose)
	else
	  echo "docker compose is required." >&2
	  exit 1
	fi

	"${COMPOSE[@]}" up -d --no-build

	for _ in $(seq 1 60); do
	  if "${DOCKER}" exec devbox paseo daemon status >/dev/null 2>&1; then
		"${DOCKER}" exec -it devbox paseo daemon status
		printf '\n\nPaseo server is running at: http://localhost:6768\n\n'
	    break
	  fi
	  sleep 1
	done

# Pair local clients after `just dev`.
pair: pair-paseo pair-t3code

# Pair a local client with the Paseo daemon.
pair-paseo:
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"

	"${DOCKER}" exec -it devbox paseo daemon pair

# Issue a local T3 Code pairing link.
pair-t3code:
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"

	"${DOCKER}" exec -it devbox t3code-pair

# Stop the dev container without removing volumes.
stop:
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"

	if "${DOCKER}" compose version >/dev/null 2>&1; then
	  COMPOSE=("${DOCKER}" compose)
	elif command -v docker-compose >/dev/null 2>&1; then
	  COMPOSE=(docker-compose)
	else
	  echo "docker compose is required." >&2
	  exit 1
	fi

	"${COMPOSE[@]}" stop

# Stop the dev container and remove the local dev image. Keeps ./data.
clean:
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"

	if "${DOCKER}" compose version >/dev/null 2>&1; then
	  COMPOSE=("${DOCKER}" compose)
	elif command -v docker-compose >/dev/null 2>&1; then
	  COMPOSE=(docker-compose)
	else
	  echo "docker compose is required." >&2
	  exit 1
	fi

	"${COMPOSE[@]}" down --volumes --remove-orphans
	"${DOCKER}" image rm "{{dev_image}}" >/dev/null 2>&1 || true

login:
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"
	DOCKER_CONFIG_DIR="${DOCKER_CONFIG:-${HOME}/.docker}"
	DOCKER_CONFIG_FILE="${DOCKER_CONFIG_DIR}/config.json"

	if [ -f "${DOCKER_CONFIG_FILE}" ] \
	  && grep -Eq '"(https://index\.docker\.io/v1/|docker\.io|registry-1\.docker\.io)"[[:space:]]*:' "${DOCKER_CONFIG_FILE}"; then
	  echo "Docker Hub login already configured."
	  exit 0
	fi

	"${DOCKER}" login docker.io -u arvigeus

publish: login
	#!/usr/bin/env bash
	set -euo pipefail

	DOCKER="${DOCKER:-docker}"
	IMAGE="{{image}}"
	NAMESPACE="${IMAGE%%/*}"
	REPOSITORY="${IMAGE#*/}"

	latest_version="$(
	  curl -fsSL "https://hub.docker.com/v2/repositories/${NAMESPACE}/${REPOSITORY}/tags?page_size=100&ordering=last_updated" \
	    | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next((tag.get("name","") for tag in data.get("results",[]) if tag.get("name") and tag.get("name")!="latest"), ""))'
	)" || latest_version=""

	if [ -n "${latest_version}" ]; then
	  echo "Latest Docker Hub version: ${latest_version}"
	else
	  echo "Latest Docker Hub version: unknown"
	fi

	read -r -p "New version to publish: " IMAGE_VERSION
	if [ -z "${IMAGE_VERSION}" ]; then
	  echo "Version is required." >&2
	  exit 1
	fi
	if [ "${IMAGE_VERSION}" = "latest" ]; then
	  echo "Use a version tag, not 'latest'." >&2
	  exit 1
	fi

	just build "${IMAGE_VERSION}"

	"${DOCKER}" push "${IMAGE}:${IMAGE_VERSION}"
	"${DOCKER}" push "${IMAGE}:latest"
