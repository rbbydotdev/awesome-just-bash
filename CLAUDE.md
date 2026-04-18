# CLAUDE.md

You are in an awesome-list automation template. This repo currently runs for `just-bash` — new users want to run it for their own subject.

**If a new user is setting this up for the first time, read `.docs/START_HERE.md` and follow it as a wizard.** Ask the questions, make the edits, run the test.

## One-line architecture

Weekly cron → `scripts/discover.sh` (8-stage filter pipeline + one Sonnet call) → draft PR with checkboxes → user comments `/apply` → `apply-discover.yml` inserts checked entries into `README.md` and auto-merges.

## Key files

- `scripts/discover.sh` — the pipeline (discovery, filters, LLM triage, PR creation)
- `scripts/checks.md` — yes/no quality gates the LLM answers
- `scripts/triage-prompt.md` — LLM instructions
- `scripts/insert_entries.py` — markdown insertion (auto-creates new categories)
- `.github/workflows/discover.yml` — Monday 09:00 UTC cron
- `.github/workflows/apply-discover.yml` — `/apply` comment handler
- `README.md` — the awesome list itself (section headings = categories)

## What's subject-specific today

Hardcoded references to `just-bash` / `vercel-labs/just-bash` / `rbbydotdev/awesome-just-bash` / `2025-12-23` / `justbash.dev` live in: `scripts/discover.sh`, `scripts/triage-prompt.md`, `scripts/checks.md` (one check name), and `README.md`. The wizard replaces them.
