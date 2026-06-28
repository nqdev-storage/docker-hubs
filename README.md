# docker-hubs

Custom Docker image + compose setup for [OpenCode](https://github.com/anomalyco/opencode) — self-hosted AI code tool router. Extends the base image with Python, Node.js, Chromium, Playwright MCP, and CLI tools.

## Quick start

```bash
# Prerequisites: .env file with OPENCODE_SERVER_USERNAME / OPENCODE_SERVER_PASSWORD

# Build & start
docker-compose -f opencode/docker-compose.yml up -d --build --force-recreate --remove-orphans

# Open: http://localhost:10026

# Shell
docker exec -it opencode-10026 script -q -c "bash"

# Stop
docker-compose -f opencode/docker-compose.yml down -v --remove-orphans
```

## Architecture

```
opencode/
  VERSION             # Current version (1.17.11)
  Dockerfile          # FROM ghcr.io/anomalyco/opencode:1.17.11
                      # Adds: python3, nodejs, git, chromium, curl, bash
                      # MCP config: playwright (local) + slim-tools (remote)
  docker-compose.yml  # Port 10026:4096, privileged, 4 CPU / 8G RAM

.github/workflows/
  opencode-docker-publish.yml   # Tag push v* → GHCR
  changelog.yml                 # Tag push v* → CHANGELOG-NQDEV.md
```

**Container**: `opencode-10026` — privileged (MITM networking), Cloudflare DNS, persistent volumes for config/data.

**MCP tools** baked into image:
- **playwright** — browser automation via `@playwright/mcp@latest`, headless Chromium
- **slim-tools** — remote web search/fetch via `https://slim.tools/mcp`

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_SERVER_USERNAME` | `opencode` | Web UI username |
| `OPENCODE_SERVER_PASSWORD` | `password` | Web UI password |

Create `.env` file in `opencode/` or repo root.

## Publishing

Trigger: `git tag v* && git push --tags` or manual `workflow_dispatch`.

- **GHCR**: `ghcr.io/nqdev-outsource/opencode` (active)
- **Docker Hub**: `quyit/opencode` (currently disabled)
- **Tags**: `{VERSION}-rc{RUN}-manual` (manual) or `{VERSION}-rc{RUN}` + `latest` (tag push)

## Project structure

```
docker-hubs/
├── opencode/
│   ├── VERSION              # Source of truth for version
│   ├── Dockerfile           # Image definition
│   ├── docker-compose.yml   # Container orchestration
│   └── data/                # Persistent volumes (gitignored)
├── .github/
│   ├── workflows/           # CI/CD pipelines
│   └── actions/set-version/ # Composite action (reads root VERSION)
├── docs/
│   └── BUSINESS.md          # Business process documentation
└── README.md
```

## Known issues

- Docker Hub publish commented out in workflow
- `docker-compose.yml` image tag (`1.17.9`) out of sync with `opencode/VERSION` (`1.17.11`)
- `set-version` action reads root `VERSION`, not `opencode/VERSION`
- Changelog workflow pushes directly to default branch (no PR)
