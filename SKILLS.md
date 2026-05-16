# Claude Skills

User-invokable skills that are particularly useful for this repo. Type `/<skill-name>` to invoke.

## Most relevant here

- **`/review`** — Review a PR. Use before merging anything that touches `lib/services/`, `lib/state/app_state.dart`, or migration-coupled code (since the schema is shared with the web app).
- **`/security-review`** — Scan pending changes for security issues. Run before pushing anything touching auth (`signIn`/`signUp`), token generation (`_generatePayToken`), or RLS-adjacent queries.
- **`/simplify`** — Audit recent changes for reuse and dead code. Useful after a feature lands and before opening a PR.
- **`/init`** — Generate / refresh CLAUDE.md from current codebase state. Use sparingly; the current CLAUDE.md is hand-curated.

## Workflow skills

- **`/loop`** — Run a recurring task (e.g. `/loop 5m flutter analyze` while iterating on a hot path).
- **`/schedule`** — Schedule a remote agent on a cron. Useful for daily dependency / lint checks.
- **`/fewer-permission-prompts`** — Scan transcripts and add a project allowlist to `.claude/settings.local.json`. Run after a session where you hit lots of prompts.
- **`/update-config`** — Modify Claude Code settings (hooks, permissions, env). Use this rather than hand-editing `.claude/settings.local.json` for non-trivial changes.

## Less relevant here

- `/claude-api` — only fires when editing code that imports `anthropic` / `@anthropic-ai/sdk`. Not used in this Flutter app (we go direct to Gemini / Groq / OpenRouter).
- `/keybindings-help` — IDE-side personalization; not project-specific.

## Adding a project skill

Skills live in `.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`). Keep each under one screen. The `description` is what Claude uses to choose between skills — be specific about when the skill should fire. None defined yet for this repo.
