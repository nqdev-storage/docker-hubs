# AGENTS.md

## Project Purpose
This repository contains a custom Docker image and compose setup for **OpenCode**, a self-hosted AI code tool router. It extends the base `ghcr.io/anomalyco/opencode` image with additional tools and configurations.

## Tech Stack
- **Base Image**: `ghcr.io/anomalyco/opencode` (Alpine-based)
- **Languages/Runtimes**: Python 3, Node.js
- **Core Tools**: Git, Chromium, Playwright MCP, Curl, Bash
- **Containerization**: Docker, Docker Compose
- **MCP Servers**: Playwright (local), Slim Tools (remote)

## Key Directories
- `opencode/`: Contains the Dockerfile, docker-compose.yml, and other OpenCode-specific configurations.
- `playwright-mcp/`: Contains Docker configuration for a dedicated Playwright MCP server.
- `claude-rc/`: Docker image + compose for Claude Code Remote Control (`claude remote-control`, published as `ghcr.io/nqdev-storage/claude-rc`). Base `node:22-bookworm-slim`, runs as user `node`, ships claude-memory-hub, localtunnel, bun, Chromium. `include/` is copied into the image (one sub-dir per `COPY`). Details in `claude-rc/README.md`.
- `docs/`: Business-facing docs (`BUSINESS.md`).
- `.claude/rules/code-rules.md`: Agent policies (testing, comment label, DB execution, git commit).
- `.github/workflows/`: CI/CD pipeline definitions (one publish workflow per image: opencode, playwright-mcp, claude-rc).

## Essential Commands

**Local Development & Operations:**
- **Build & Start**:
  ```bash
  docker-compose -f opencode/docker-compose.yml up -d --build --force-recreate --remove-orphans
  ```
- **Stop & Clean**:
  ```bash
  docker-compose -f opencode/docker-compose.yml down -v --remove-orphans
  ```
- **Enter Container**:
  ```bash
  docker exec -it opencode-10026 script -q -c "bash"
  ```
- **View Logs**:
  ```bash
  docker logs opencode-10026 -f
  ```

**Dockerfile & Image Specifics:**
- The `opencode/Dockerfile` installs Python, Node.js, Git, Chromium, and npm.
- It configures Playwright MCP locally and Slim Tools MCP remotely via `/root/.config/opencode/mcp.json`.
- The `opencode/docker-compose.yml` runs the container as root with `privileged: true`, maps ports `10026:4096`, and sets resource limits.
- The `playwright-mcp/docker-compose.yml` configures a separate Playwright MCP service, installing Chrome and running Playwright with specific capabilities.

## Architecture
The setup involves a main OpenCode service container and potentially a separate Playwright MCP container, orchestrated by Docker Compose. The OpenCode container acts as a router, extending base functionality with tools like Playwright for browser automation.

## Known Gotchas & Constraints
- The main OpenCode container runs as `root` and is `privileged: true`, indicating a need for elevated system access, likely for network interception (MITM) capabilities.
- `claude-rc` bind-mounts `./data/claude-config` and `./data/claude-memory-hub` over image paths, hiding the baked-in `settings.json`, hooks and runtime until `data/` is seeded from `include/` (see `claude-rc/README.md` §5.0). Never set Anthropic API keys/base URL in its `.env` — Remote Control requires `claude auth login`.
- Image versions live in per-directory `VERSION` files (plus root `.version.txt`); compose image tags carry an `-rcN` build suffix.
- Local development requires a `.env` file with `OPENCODE_SERVER_USERNAME` and `OPENCODE_SERVER_PASSWORD`.
