# CLAUDE.md

Before doing any significant work in this repository, read `AGENTS.md`.

- `AGENTS.md` is the canonical source of project knowledge (architecture, conventions, commands, gotchas).
- Do not duplicate project knowledge here — this file is only a pointer.
- Whenever you learn something durable about this project, update `AGENTS.md` accordingly.

> **Database Safety** — Claude never executes SQL (DDL/DML/migrations) against any database. Write it in chat tagged `-- NOT run by Claude — cần DBA review`; read-only `SELECT` is exempt. See [`.claude/rules/code-rules.md`](.claude/rules/code-rules.md).

> **Git Safety** — Never `git commit` (incl. `--amend`) without showing the files + proposed message and getting explicit confirmation each time. No push/reset --hard/rebase/merge/tag/branch changes unless asked. Read-only git is fine. See [`.claude/rules/code-rules.md`](.claude/rules/code-rules.md).

> **Sub-directory guidance** — `opencode/CLAUDE.md`, `playwright-mcp/CLAUDE.md`, `claude-rc/CLAUDE.md`, `docs/CLAUDE.md`.
