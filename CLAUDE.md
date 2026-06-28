# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Custom Docker image + compose setup for **OpenCode** — a self-hosted AI code tool router. Adds Python, Node, Playwright MCP, and CLI tools to the base opencode image.

## Key commands

```bash
# Build & start
docker-compose -f opencode/docker-compose.yml up -d --build --force-recreate --remove-orphans

# Stop
docker-compose -f opencode/docker-compose.yml down -v --remove-orphans

# Enter container
docker exec -it opencode-10026 script -q -c "bash"
```

## Project structure

```
opencode/
  Dockerfile          # Alpine-based, extends ghcr.io/anomalyco/opencode:1.15.10
                      # Adds: python3, nodejs, git, chromium, curl, bash, Playwright MCP
  docker-compose.yml  # Service def: port 10026, volume mounts, resource limits (4 CPU, 8G RAM)
                      # DNS, extra_hosts, privileged mode for MITM networking

.github/
  workflows/
    opencode-docker-publish.yml   # On tag push v*: build & push to GHCR + Docker Hub
    changelog.yml                 # On tag push v*: auto-generate CHANGELOG-NQDEV.md
  actions/set-version/action.yml  # Composite action to read VERSION file
  dependabot.yml                  # No auto-updates configured
```

## CI/CD

- Tag push `v*` triggers Docker build to `ghcr.io/nqdev-outsource/docker-hubs` and `quyit/9router` (Docker Hub)
- Docker tags: semver `{{version}}`, `latest`, or `26.5.<run_number>-manual` for manual dispatch
- Changelog workflow uses `auto-changelog` with keepachangelog template

## Docker Hub image

Published as `quyit/opencode` (currently tagged `1.17.9`). The compose file references it directly; Dockerfile builds it locally.

## Notes

- Container runs privileged (MITM networking needed)
- `.env` file required locally for `OPENCODE_SERVER_*` vars
- Data volumes: `data/oc-local`, `data/oc-config`, `data/wps`
