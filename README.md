# Paseo Dev

This repository builds `devbox`: a Docker image that bundles several AI coding CLI tools into a persistent, self-updating container intended for VPS use.

The image includes:

- [Paseo](https://paseo.sh) — multi-agent coding orchestrator (runs as the server process)
- [T3 Code](https://github.com/pingdotgg/t3code) — browser-based coding agent workspace (runs as a sibling server)
- [Claude Code](https://code.claude.com) (`claude`) — Anthropic's AI coding agent
- [OpenAI Codex CLI](https://github.com/openai/codex) (`codex`) — OpenAI's AI coding agent
- [Mistral Vibe](https://docs.mistral.ai/vibe/code/cli/install-setup) (`vibe`) — Mistral's AI coding agent
- [OpenCode](https://opencode.ai) — SST's terminal AI coding assistant
- [Grok CLI](https://www.npmjs.com/package/@xai-official/grok) (`grok`) — xAI Grok coding agent used by T3 Code
- [GitHub Copilot CLI](https://github.com/github/copilot-cli) (`copilot`) — GitHub's AI coding agent
- [Fresh](https://github.com/fresh2dev/fresh) (`fresh`) — terminal editor used by T3 Code environments
- [Pi](https://pi.dev) (`pi`) — multi-provider AI coding agent
- [GitHub CLI](https://cli.github.com) (`gh`) — required by Paseo for PR-aware features
- [GitLab CLI](https://gitlab.com/gitlab-org/cli) (`glab`) — GitLab MR and pipeline management
- [Azure CLI](https://docs.microsoft.com/cli/azure) (`az`) — Azure resource management
- GnuPG (`gpg`) — optional Git commit signing and runtime verification support
- [mise](https://mise.jdx.dev) — polyglot runtime version manager
- Node.js LTS (managed by mise)

All tools are installed under `/home/dev` (user-local). Projects live at `/workspace`. The Paseo daemon starts automatically and listens on port `6767`; the self-hosted web app is served on port `6768`; T3 Code listens on port `3773`. Missing tools are installed on startup, and all tools auto-update every 24 hours while the container is running.

The same `/usr/local/bin/vibe-install` script runs during container startup. This preserves credentials in the `/home/dev` mount while still letting newly added tools appear in existing deployments.

The web app is built from the matching Paseo release source during the image build.
T3 Code is built from upstream source during the image build and stores its runtime state under `/home/dev/.local/share/t3code`.

## Quick Start

Build and start with Docker Compose:

```bash
docker compose up -d --build
docker compose logs -f dev
```

For local image testing, use the `just` recipes:

```bash
just build                  # build the image with the released @getpaseo/cli package
just dev                    # build the same image and start compose
just pair                   # show local Paseo and T3 Code pairing links after just dev
just stop                   # stop the dev container without removing volumes
just publish                # prompt for a version, then push that tag and latest to Docker Hub
just clean                  # stop compose and remove the local dev image; keeps ./data
```

Local development uses bind-mounted state under `./data`: `./data/devbox/home` for `/home/dev` and `./data/workspace` for `/workspace`. The container also mounts your local `~/.ssh` read-only and `~/.gnupg` read-write, matching the production layout.

Authenticate each tool once — credentials persist in the `/home/dev` mount:

```bash
docker exec -it devbox claude auth login          # Claude subscription (Pro/Max/Team)
docker exec -it devbox codex login --device-auth  # ChatGPT subscription
docker exec -it devbox opencode auth login        # OpenCode account
docker exec -it devbox gh auth login              # GitHub — enables PR creation, branch push, merge
docker exec -it devbox glab auth login            # GitLab — enables MR creation, branch push, merge
docker exec -it devbox az login --use-device-code # Azure — enables Azure resource management
docker exec -it devbox copilot login              # GitHub Copilot subscription (or auto-uses gh credentials)
docker exec -it devbox grok login --device-auth   # Grok account, or set XAI_API_KEY for API-key auth
docker exec -it devbox pi                         # Pi: type /login and select a provider
docker exec -it devbox vibe --setup               # Mistral Vibe: configure an API key or account access
```

## Pairing

### Development

After `just dev`, use the local pairing helper:

```bash
just pair
```

This runs both local pairing commands:

```bash
just pair-paseo
just pair-t3code
```

Paseo prints a QR code or link for the Paseo app. T3 Code prints a `Pair URL` using `http://localhost:3773`.

### Production

Pair a client with the Paseo daemon:

```bash
docker exec -it devbox paseo daemon pair
```

Issue a T3 Code pairing link:

```bash
docker exec -it devbox t3code-pair
```

`T3CODE_BASE_URL` must be set.

## Authentication

The `/home/dev` mount stores all CLI credentials. Logins survive container restarts and image rebuilds as long as the mounted data is kept.

Each auth command either prints a URL to open in your local browser or a device code to enter on the provider's website. The OAuth callback does not need to reach the container — only the code or token is pasted back into the terminal.

If `OPENROUTER_API_KEY` is set in the container environment, startup configures supported agents with that key automatically.
For Grok, set `XAI_API_KEY` for API-key auth or run `grok login --device-auth` once to cache credentials.

To sign out: `claude auth logout`, `codex logout`, `gh auth logout`, etc.

For signed Git commits, import an existing key into the persisted `/home/dev` mount or
generate a new one inside the container:

```bash
# Existing key exported from your host:
# gpg --armor --export-secret-keys YOUR_KEY_ID > private.asc
docker cp private.asc devbox:/home/dev/private.asc
docker exec -it devbox gpg --import /home/dev/private.asc
docker exec -it devbox rm /home/dev/private.asc

# Or create a new key inside the container:
docker exec -it devbox gpg --full-generate-key
```

Then configure Git to sign commits:

```bash
docker exec -it devbox gpg --list-secret-keys --keyid-format=long
docker exec -it devbox git config --global user.signingkey YOUR_KEY_ID
docker exec -it devbox git config --global commit.gpgsign true
docker exec -it devbox git config --global gpg.program gpg
```

If the key is new, add its public half to GitHub:

```bash
docker exec -it devbox sh -lc 'gpg --armor --export YOUR_KEY_ID | gh gpg-key add -'
```

## Connecting to Paseo

The daemon binds to `0.0.0.0:6767` and is mapped to the same port on the host. Clients connect directly to `http://your-vps-ip:6767` or through the Paseo relay for encrypted remote access.

The bundled web app listens on `0.0.0.0:6768`. If you serve it on a separate origin, for example `https://paseo.example.com` while the daemon is at `https://dev.example.com`, set `PASEO_CORS_ORIGINS=https://paseo.example.com` on the daemon container.

T3 Code listens on `0.0.0.0:3773` and uses the same `/workspace` mount as the other tools.

OpenCode's web UI is disabled by default. To enable it, set `OPENCODE_SERVER_PASSWORD`; it listens on `0.0.0.0:4096`.

Port `5173` is exposed for Vite development servers. In `docker-compose.yml` it is commented out by default; if you enable it, start Vite with `--host 0.0.0.0` (for example: `npm run dev -- --host 0.0.0.0`).

**Check daemon status:**

```bash
docker exec -it devbox paseo daemon status
```

If status reports the daemon as unreachable while the process is running, verify the
local API directly. The container binds the daemon to `0.0.0.0:6767` so reverse proxies can
reach it, but loopback is the clearest address for local checks:

```bash
docker exec -it devbox sh -lc 'curl -i http://127.0.0.1:6767/api/health'
docker exec -it devbox paseo provider ls --host 127.0.0.1:6767
```

**Set a password** (recommended when the port is exposed to the internet):

```bash
# Either set PASEO_PASSWORD in a .env file before first start, or run interactively:
docker exec -it devbox paseo daemon set-password
```

By default `PASEO_HOSTNAMES=true` permits any `Host` header, which is convenient behind a reverse proxy or VPN. To restrict to specific names, set `PASEO_HOSTNAMES=localhost,127.0.0.1,myvps.example.com` in a `.env` file alongside `docker-compose.yml`.

## Working with Projects

All projects live inside `/workspace`. Use `git` or `gh` to bring code in:

```bash
docker exec -it devbox bash
cd /workspace
gh repo clone you/myproject
```

If `/workspace` was created by an older image and is not writable, repair the existing volume once:

```bash
docker exec -u root devbox chown -R dev:dev /workspace
```

From there, point any tool at the project:

```bash
cd /workspace/myproject
paseo    # or: claude, codex, vibe, opencode
```

## Updates

Tools are updated automatically **every 24 hours** — a background loop re-runs the same pass while the container is alive. The daemon keeps running during the update.

To disable automatic updates, set `AUTO_UPDATE=false` in a `.env` file. To restart quickly without waiting for an update pass:

```bash
AUTO_UPDATE=false docker compose restart dev
```

## Runtime Environment

| Variable                   | Default        | Purpose                                                      |
| -------------------------- | -------------- | ------------------------------------------------------------ |
| `AUTO_UPDATE`              | `true`         | Run update pass every 24 h                                   |
| `PASEO_HOSTNAMES`          | `true`         | Hostname allowlist for DNS-rebinding protection              |
| `PASEO_PASSWORD`           |                | Pre-set daemon password (hashed at startup)                  |
| `OPENROUTER_API_KEY`       |                | Optional OpenRouter API key for supported tools              |
| `XAI_API_KEY`              |                | Optional xAI API key for T3 Code's Grok provider             |
| `T3CODE_BASE_DIR`          | `/home/dev/.local/share/t3code` | T3 Code state directory used by `t3code-pair` |
| `T3CODE_BASE_URL`          |                | Public T3 Code URL used by `t3code-pair`; set by compose |
| `OPENCODE_SERVER_USERNAME` |                | Username for OpenCode's web UI                               |
| `OPENCODE_SERVER_PASSWORD` |                | Enable and password-protect OpenCode's web UI on port `4096` |

## Development Ports

| Port   | Purpose                           | Notes                                          |
| ------ | --------------------------------- | ---------------------------------------------- |
| `3773` | T3 Code web server                | Enabled by default                             |
| `4096` | OpenCode web UI                   | Enabled when `OPENCODE_SERVER_PASSWORD` is set |
| `5173` | Vite dev server                   | Start Vite with `--host 0.0.0.0`               |
| `6767` | Paseo daemon                      | Main API/WebSocket endpoint                    |
| `6768` | Bundled self-hosted Paseo web app | Static web client                              |

## Mounts

| Mount point | Local default          | Production example       | Purpose                                                                                         |
| ----------- | ---------------------- | ------------------------ | ----------------------------------------------------------------------------------------------- |
| `/home/dev` | `./data/devbox/home`   | `${DATA}/devbox/home`    | Persists tool installations, credentials, and mise state; missing tools are installed on startup |
| `/workspace` | `./data/workspace`    | `${HOST_WORKSPACE}`      | Project files                                                                                   |
| `/home/dev/.ssh` | `${HOME}/.ssh` read-only | `${HOST_HOME}/.ssh` read-only | SSH keys and config                                                                      |
| `/home/dev/.gnupg` | `${HOME}/.gnupg` | `${HOST_HOME}/.gnupg`    | GnuPG keys and agent data                                                                       |

> **Warning**: local credentials and projects are stored under `./data`. Production credentials and projects are stored in the host paths configured by the deployment compose file.
