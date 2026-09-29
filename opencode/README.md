# OpenCode (Docker)

Custom Docker image + compose for [OpenCode](https://opencode.ai/docs/#windows) — a self-hosted AI code tool router. Extends the base `ghcr.io/anomalyco/opencode` image with Python, Node.js, Chromium, Git, and a baked-in Playwright MCP server.

See the root [`AGENTS.md`](../AGENTS.md) for repo-wide architecture, CI/CD, and gotchas — this file covers only what's inside `opencode/`.

## Quick start

```bash
# Prerequisites: .env in this directory with OPENCODE_SERVER_USERNAME / OPENCODE_SERVER_PASSWORD

# Pull & start (uses the prebuilt GHCR image, not a local build)
docker-compose up -d --force-recreate --remove-orphans

# Open: http://localhost:10029

# Shell into the container
docker exec -it opencode-10029 script -q -c "bash"

# Stop & clean
docker-compose down -v --remove-orphans
```

`docker-compose.yml` currently pulls a prebuilt image rather than building from the local `Dockerfile` — the `build:` block is commented out. Uncomment it (and swap the `image:` line) to build locally instead.

## What's in the image

- **Base**: `ghcr.io/anomalyco/opencode:2.0.18` (Alpine)
- **Added packages**: `python3`, `python3-dev`, `py3-pip`, `git`, `bash`, `util-linux`, `coreutils`, `curl`, `chromium`, `nodejs`, `npm`
- **MCP config** written to `/root/.config/opencode/mcp.json`:
  - `playwright` (local) — `@playwright/mcp@latest`, headless Chromium, caps: `network,storage,testing,vision,devtools`
- **Entrypoint**: `opencode` (compose runs `web --hostname 0.0.0.0 --port 4096`)

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Image definition, built from `ghcr.io/anomalyco/opencode` |
| `docker-compose.yml` | Container orchestration (port, volumes, resource limits) |
| `VERSION` | Source of truth for the base image version pinned in `Dockerfile` |
| `CLAUDE.md` | Pointer for AI agents to `AGENTS.md` |
| `data/` | Persistent volumes (gitignored) |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_SERVER_USERNAME` | `opencode` | Web UI username |
| `OPENCODE_SERVER_PASSWORD` | `password` | Web UI password |
| `WAKATIME_API_KEY` | `ak-api-key` | Optional, read by WakaTime plugin/CLI |

Create `.env` in this directory to override defaults.

## Container details

- Name: `opencode-10029`, port `10029:4096`
- Image: `ghcr.io/nqdev-storage/opencode:2.0.18-rc11-manual` (pinned in `docker-compose.yml`; older tags kept commented out for quick rollback)
- Runs as `root` with `privileged: true` (needed for MITM-style network interception)
- Custom DNS: Cloudflare (`1.1.1.1`/`1.0.0.1`) + Google (`8.8.8.8`/`8.8.4.4`)
- Resource limits: 4 CPU / 8G RAM, reserving 256M
- Persistent volumes:
  - `./data/oc-local` → `/root/.local/share/opencode/`
  - `./data/oc-config` → `/root/.config/opencode/`
  - `./data/wps` → `/app/data`

## Known issues

- The `docker-compose.yml` header comment still reads "9Router — Connect All AI Code Tools..." (leftover from a copy-paste); the service it defines is OpenCode.
- `docker-compose.yml` runs a prebuilt GHCR tag (`2.0.18-rc11-manual`), not the `Dockerfile` in this directory — the two can drift if the `Dockerfile` is changed without publishing and re-pinning a matching tag.
