# CLAUDE.md (claude-rc/)

Before doing any significant work in this directory, read the root [`AGENTS.md`](../AGENTS.md) and this directory's [`README.md`](README.md).

- This directory is the Claude Code Remote Control image (`ghcr.io/nqdev-storage/claude-rc`): `Dockerfile`, `docker-compose.yml`, `VERSION`, `.env.example`, and `include/` (files copied into the image).
- [`README.md`](README.md) is the detailed reference (tools in image, volumes, login flow, localtunnel) — prefer it over writing new guidance here.
- `include/` maps one sub-directory to one `COPY` line in the `Dockerfile`. Adding a new `include/<name>/` requires adding the matching `COPY`; order matters (`include/.claude/` before the `claude-memory-hub install` step, `include/claude-memory-hub/` after it).
- `scripts/` (outside `include/`) holds scripts that run, or are needed to run, inside the image (copied to `/opt/scripts/`, on PATH, chmod 755, LF line endings enforced by `.gitattributes`). Java/Maven are intentionally NOT baked in (image size) — `10-install-java-maven.sh` installs them on demand.
- Never set `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`, a custom `ANTHROPIC_BASE_URL`, `DISABLE_GROWTHBOOK` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` — Remote Control stops working. Login is `claude auth login` only.
- Never commit `.env` or `data/` (login, workspace, memory DB). Only `.env.example` is tracked.
- Build context is this directory (`context: claude-rc`), not the repo root.
