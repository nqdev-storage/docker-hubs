# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Custom Docker image + compose setup for **OpenCode** (self-hosted AI code tool router). Extends `ghcr.io/anomalyco/opencode` with Python, Node, Chromium, Playwright MCP, and CLI tools.

## Key commands

```bash
# Build & start (local build from Dockerfile)
docker-compose -f opencode/docker-compose.yml up -d --build --force-recreate --remove-orphans

# Stop & clean volumes
docker-compose -f opencode/docker-compose.yml down -v --remove-orphans

# Enter container
docker exec -it opencode-10026 script -q -c "bash"

# View logs
docker logs opencode-10026 -f
```

## Architecture

```
opencode/
  VERSION             # Current semver (e.g. 1.17.11)
  Dockerfile          # Alpine-based, FROM ghcr.io/anomalyco/opencode:1.17.11
                      # Adds: python3, nodejs, git, chromium, curl, bash
                      # Writes Playwright MCP + slim.tools MCP config to mcp.json
  docker-compose.yml  # Port 10026:4096, privileged mode, 4 CPU / 8G RAM
                      # DNS (Cloudflare + Google + local), extra_hosts for host.docker.internal
                      # Volumes: data/oc-local, data/oc-config, data/wps

.github/
  workflows/
    opencode-docker-publish.yml   # Tag push v*: build & push to GHCR; Docker Hub publish commented out
    changelog.yml                 # Tag push v*: auto-changelog → CHANGELOG-NQDEV.md
  actions/set-version/action.yml  # Composite: read VERSION file → GITHUB_ENV
```

## Image publishing

- **GHCR**: `ghcr.io/nqdev-outsource/docker-hubs` (active)
- **Docker Hub**: `quyit/opencode` (currently **disabled** — login step commented out in workflow)
- **Tags**: `{{VERSION}}-rc{{run_number}}`, `latest` on tag push; `{{VERSION}}-rc{{run_number}}-manual` on `workflow_dispatch`
- **Build cache**: registry cache at `ghcr.io/.../opencode:buildcache` (mode=max)
- **Trigger**: push tag `v*` or manual `workflow_dispatch`

## VERSION

- Source of truth: `opencode/VERSION` (read by `cat opencode/VERSION` in publish workflow)
- The set-version action reads root `VERSION` (rarely used — only by changelog workflow)
- Update `opencode/VERSION` and `docker-compose.yml` image tag when bumping

## MCP config

Built into the Dockerfile at `/root/.config/opencode/mcp.json`:
- **playwright** (local): npx `@playwright/mcp@latest`, chromium headless, caps=network,storage,testing,vision,devtools
- **slim-tools** (remote): `https://slim.tools/mcp`, 5s timeout

## Notes

- Container runs **privileged** (MITM networking for host traffic interception)
- `.env` file required locally with `OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD`
- Base image is `ghcr.io/anomalyco/opencode` — check for upstream updates
