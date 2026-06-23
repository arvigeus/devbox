# syntax=docker/dockerfile:1.7

ARG PASEO_VERSION=v0.1.98
ARG T3CODE_VERSION=v0.0.27

FROM node:24-trixie AS paseo-web-build

ARG PASEO_VERSION

ENV CI=true \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_PROGRESS=false \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    CYPRESS_INSTALL_BINARY=0

WORKDIR /src
RUN git clone --depth 1 --branch "${PASEO_VERSION}" https://github.com/getpaseo/paseo.git .
RUN --mount=type=cache,target=/root/.npm \
    npm ci --workspace=@getpaseo/app --include-workspace-root
RUN npm run build:web --workspace=@getpaseo/app

FROM node:24-trixie AS t3code-build

ARG T3CODE_VERSION

ENV PNPM_HOME=/pnpm \
    PNPM_STORE_DIR=/pnpm/store
ENV PATH="${PNPM_HOME}:${PATH}"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    git \
    make \
    pkg-config \
    python3

RUN corepack enable \
    && corepack prepare pnpm@10.24.0 --activate

WORKDIR /src
RUN git clone --depth 1 --branch "${T3CODE_VERSION}" https://github.com/pingdotgg/t3code.git .

RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile --store-dir "${PNPM_STORE_DIR}"

RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm --filter @t3tools/web build \
    && pnpm --filter t3 build:bundle \
    && pnpm --filter t3 deploy --prod --legacy /opt/t3code-runtime \
    && mkdir -p /opt/t3code-runtime/dist/client \
    && cp -R apps/web/dist/. /opt/t3code-runtime/dist/client/

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# WakeMeOps and Mise repositories
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    extrepo \
    gnupg \
    && curl -fsSL https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository | bash \
    && extrepo enable mise \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    lbzip2 \
    procps \
    ripgrep \
    tini \
    xsel xdg-utils \
    unzip \
    jq \
    azure-cli \
    github-cli \
    glab \
    mise

RUN useradd -m -u 1000 -s /bin/bash dev \
    && mkdir -p /workspace \
    && chown dev:dev /workspace

COPY --chmod=755 bin/json.sh /usr/local/bin/json
COPY --chmod=755 bin/t3code-pair.sh /usr/local/bin/t3code-pair
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 vibe-install.sh /usr/local/bin/vibe-install
COPY --chmod=755 vibe-update.sh /usr/local/bin/vibe-update
COPY --from=paseo-web-build /src/packages/app/dist /opt/paseo-web
COPY --from=t3code-build --chown=dev:dev /opt/t3code-runtime /opt/t3code

USER dev
WORKDIR /home/dev

ENV HOME=/home/dev
ENV PATH="/home/dev/.local/share/mise/shims:/home/dev/.local/bin:/home/dev/.opencode/bin:${PATH}"
ENV NPM_CONFIG_PREFIX="/home/dev/.local"

EXPOSE 3773 4096 5173 6767 6768

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["paseo", "daemon", "start", "--foreground"]
