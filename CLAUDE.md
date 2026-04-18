# CLAUDE.md

You are in an awesome-list automation template. This repo currently runs for `just-bash` — new users want to run it for their own subject.

**If a new user is setting this up for the first time, read `.docs/START_HERE.md` and follow it as a wizard.** Ask the questions, edit `awesome.config.yml`, run the test.

## One-line architecture

Weekly cron → `scripts/discover.sh` (8-stage filter pipeline + one Sonnet call) → draft PR with checkboxes → user comments `/apply` → `apply-discover.yml` inserts checked entries into `README.md` and auto-merges.

## Key files

- `awesome.config.yml` — **single source of truth for subject-specific values** (name, canonical repo, search queries, thresholds)
- `scripts/discover.sh` — the pipeline (list-agnostic; reads everything from the config)
- `scripts/checks.md` — yes/no quality gates the LLM answers (use `{{subject.name}}` placeholders)
- `scripts/triage-prompt.md` — LLM instructions (use `{{subject.name}}` placeholders)
- `scripts/insert_entries.py` — markdown insertion (auto-creates new categories)
- `.github/workflows/discover.yml` — Monday 09:00 UTC cron
- `.github/workflows/apply-discover.yml` — `/apply` comment handler
- `README.md` — the awesome list itself (section headings = categories)

## Templating

The prompt files use `{{subject.name}}`, `{{subject.canonical_repo}}`, `{{subject.blurb}}`, `{{subject.created_at}}`, `{{subject.homepage}}` — substituted at runtime from `awesome.config.yml`. Scripts are list-agnostic.
