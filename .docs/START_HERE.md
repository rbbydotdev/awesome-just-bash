# Setup wizard

You're helping a user configure this awesome-list automation template for their own subject (i.e. the project/tool/package the list will be about). Walk through the steps below in order. **Ask the questions conversationally — don't just dump the list at them.**

---

## Step 1 — Collect inputs from the user

Ask these questions (one at a time, or in a short batch). All answers are required.

1. **Subject name** — the thing the list is about (e.g. `langchain`, `shadcn`, `just-bash`). Will appear in the list title and in every search query.
2. **Canonical GitHub repo** — the authoritative source, `owner/name` format (e.g. `langchain-ai/langchain`).
3. **Subject creation date** — when the canonical repo was created. You can fetch this yourself: `gh repo view <canonical-repo> --json createdAt --jq .createdAt`. Used as a hard filter to reject older name-collision repos.
4. **One-sentence blurb** — describes what the subject is. Will appear in the readme header and the LLM prompt (e.g. "a TypeScript framework for building LLM apps").
5. **Homepage URL** (optional) — marketing/docs site if it has one.
6. **Package name on npm/PyPI** (optional) — the installable name, if different from the repo name. Used to detect `dependencies` entries. If no package exists, say so.
7. **GitHub username/org for the new awesome list** — where this repo will live once they fork/push (e.g. `alice`). Used as the self-reference filter so the list never discovers itself.

Confirm the answers back to the user before making any edits.

---

## Step 2 — Replace subject-specific strings

There is no `awesome.config.yml` yet. Subject-specific values are embedded in a handful of files. You must update each one.

Use `Grep` to find every reference to `just-bash` / `vercel-labs/just-bash` / `rbbydotdev/awesome-just-bash` / `2025-12-23` / `justbash.dev`, then edit each occurrence with the user's values.

Files to touch (in order):

### `scripts/discover.sh`

Replace:
- `"just-bash in:name"` → `"<subject> in:name"` (the gh repo search query)
- `'from "just-bash"'` → `'from "<package-name>"'` (if they have an npm package; else keep but note it may be a weak signal)
- `'"just-bash":'` → `'"<package-name>":'` (package.json dep search; skip if no package)
- npm registry URL query `text=just-bash` → `text=<subject>`
- Name pattern regex `just[-_]?bash` → pattern matching their subject (e.g. `lang[-_]?chain`)
- `2025-12-23T00:00:00Z` (appears twice — stage 1 and stage 5) → the subject's `createdAt` date
- `rbbydotdev/awesome-just-bash` → `<user>/awesome-<subject>`
- `repos/vercel-labs/just-bash/readme` → `repos/<canonical-repo>/readme`
- package.json dep check `has("just-bash")` → `has("<package-name>")`
- Import regex `from[[:space:]]+"just-bash"|require\("just-bash"\)` → matching patterns for the subject's package name

### `scripts/triage-prompt.md`

- Every mention of `just-bash` → `<subject>`
- `vercel-labs/just-bash` → `<canonical-repo>`
- `2025-12-23` → subject's `createdAt`
- Rewrite the "What just-bash is" paragraph to describe the user's subject (use their blurb).
- Update the example one-liner descriptions at the bottom to match the new domain if helpful.

### `scripts/checks.md`

- `is_just_bash_focused` → `is_subject_focused` (and update the question text inside it, replacing `just-bash` with `<subject>`)

### `README.md`

Completely rewrite as a seed for their list. Structure:

```markdown
# Awesome <subject> [![Awesome](https://awesome.re/badge-flat.svg)](https://awesome.re)

> A curated list of resources for [<subject>](https://github.com/<canonical-repo>) — <their blurb>.

## Contents

- [Official](#official)
- [Contributing](#contributing)

## Official

- [<subject>](https://github.com/<canonical-repo>) — <short description>.

## Contributing

Contributions welcome. Open a PR adding your project.

## License

[![CC0](https://licensebuttons.net/p/zero/1.0/80x15.png)](https://creativecommons.org/publicdomain/zero/1.0/)
```

Keep it minimal — the discovery workflow will propose additions, and `insert_entries.py` auto-creates new `## Category` sections as needed. Start with just `## Official` and let categories grow organically.

After editing: verify with `grep -riE "just-bash|vercel-labs|rbbydotdev|2025-12-23|justbash\.dev" scripts/ README.md` — should return nothing. If anything still matches, handle it.

---

## Step 3 — GitHub setup

Do these via `gh` CLI. The user needs to be authenticated (`gh auth status`).

### 3a. Push to their own repo

If this is a fresh clone/fork, help them push to their GitHub account. Ask for the repo name (default: `awesome-<subject>`).

```bash
gh repo create <user>/<repo> --public --source=. --push
```

### 3b. Add the OpenRouter secret

Ask the user if they have an OpenRouter API key. If not, point them at <https://openrouter.ai/keys> and suggest they add ~$5 in credits (weekly runs cost pennies — $0.08–$0.10).

Once they have a key:

```bash
gh secret set OPENROUTER_KEY
```

(Interactive prompt — user pastes the key, it doesn't touch shell history.)

### 3c. Enable GitHub Actions PR-creation permission

This is off by default. The Monday cron will fail without it.

```bash
gh api -X PUT repos/<user>/<repo>/actions/permissions/workflow \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```

Verify:

```bash
gh api repos/<user>/<repo>/actions/permissions/workflow \
  --jq '{default_workflow_permissions, can_approve_pull_request_reviews}'
```

Both should read `"write"` and `true`.

### 3d. Set repo description + topics

```bash
gh repo edit <user>/<repo> \
  --description "A curated list of <subject> resources" \
  --add-topic awesome --add-topic awesome-list --add-topic <subject>
```

---

## Step 4 — Do a dry run

Validate the pipeline with no side effects (`DRY_RUN=1` skips the LLM call and the PR).

```bash
gh workflow run discover.yml -f dry_run=true
gh run watch
```

Expected: the job runs to stage 8 and logs "DRY_RUN=1 — done (no changes written)". If any stage errors, read the log and fix before doing a real run.

Common first-run issues:
- `pip install llm llm-openrouter` fails → usually a transient pip mirror issue, re-run
- Stage 2 filter returns 0 candidates → regex is too tight for the subject; loosen `name_pattern` in discover.sh
- Anything else → read the log carefully, debug, re-run dry

---

## Step 5 — Do a real run

Once the dry run is clean:

```bash
gh workflow run discover.yml
gh run watch
```

Should produce a draft PR with a checklist of candidates (or finish with "nothing new" if zero survive triage — rare but possible for obscure subjects).

If a PR opens: open it in the browser, check some boxes, comment `/apply`. The `apply-discover.yml` workflow should fire, insert the checked entries into `README.md`, and squash-merge automatically.

---

## Step 6 — You're done

- Cron is set for Mondays 09:00 UTC.
- Every week: PR arrives, user checks boxes + `/apply`, entries merge.
- To pause: `touch .discover.disabled && git commit -am "pause discovery" && git push`.
- To tune quality: edit `scripts/checks.md` — add/remove yes/no checks; no code changes needed.
- Costs will show in every PR footer (actual billed cost from OpenRouter, not an estimate).

If the user wants to extend (add sources, tighten filters, change schedule), point them at the progressive stages in `scripts/discover.sh` — each stage is labeled with a comment block.
