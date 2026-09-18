# CLAUDE.md (playwright-mcp/)

Before doing any significant work in this directory, read the root [`AGENTS.md`](../AGENTS.md) and this directory's own docs.

- This directory is the standalone Playwright MCP Docker service (separate from `opencode/`), with multiple Dockerfile variants (`Dockerfile`, `Dockerfile.advanced-slim`, `Dockerfile.ultra-slim`) and its own `docker-compose.yml`.
- Detailed usage, comparisons, and optimization notes already live here — prefer these over writing new guidance:
  - [`QUICK_START.md`](QUICK_START.md), [`README.md`](README.md), [`TECHNICAL_GUIDE.md`](TECHNICAL_GUIDE.md)
  - [`DOCKER_OPTIMIZATION_GUIDE.md`](DOCKER_OPTIMIZATION_GUIDE.md), [`COMPARISON_MATRIX.md`](COMPARISON_MATRIX.md), [`IMPLEMENTATION_CHECKLIST.md`](IMPLEMENTATION_CHECKLIST.md), [`INDEX.md`](INDEX.md)
- `AGENTS.md` (repo root) remains the canonical source for cross-cutting architecture/gotchas — do not duplicate its content here.
