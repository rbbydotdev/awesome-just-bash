# Setup wizard

You're helping a user configure this awesome-list automation template for their own subject (i.e. the project/tool/package the list will be about). Walk through the steps below in order. **Ask the questions conversationally — don't just dump the list at them.**

---

## Step 1 — Collect inputs from the user

Ask these questions (one at a time, or in a short batch). All answers become fields in `awesome.config.yml`.

1. **Subject name** — the thing the list is about (e.g. `langchain`, `shadcn`, `just-bash`). Will appear in the list title and in every search query.
2. **Canonical GitHub repo** — the authoritative source, `owner/name` format (e.g. `langchain-ai/langchain`).
3. **Subject creation date** — when the canonical repo was created. You can fetch this yourself: `gh repo view <canonical-repo> --json createdAt --jq .createdAt`. Used as a hard filter to reject older name-collision repos.
4. **One-sentence blurb** — describes what the subject is (e.g. "a TypeScript framework for building LLM apps"). Shown in the readme header and the LLM prompt.
5. **Homepage URL** (optional) — marketing/docs site if it has one.
6. **Package name** (optional) — the installable name on npm/PyPI if different from the repo name. If there's no published package at all, say so and we'll set `package.exists: false`.
7. **GitHub username/org for the new awesome list** — where this repo will live once they fork/push (e.g. `alice`). Used as the self-reference filter so the list never discovers itself.

Confirm the answers back to the user before making any edits.

---

## Step 2 — Edit `awesome.config.yml`

This is the **only file with subject-specific values**. Open it and update every field under `subject:`, `search:`, and `self_reference:` with the user's answers. The scripts read from it at runtime; the prompt files use `{{subject.*}}` placeholders that get substituted automatically.

Rough mapping from user answers to config fields:

| User answer | Config field |
|---|---|
| Subject name | `subject.name`, `search.npm_keyword` |
| Canonical repo | `subject.canonical_repo` |
| Creation date | `subject.created_at` |
| Blurb | `subject.blurb` |
| Homepage | `subject.homepage` |
| Package name | `subject.package.name` (set `exists: false` if none) |
| New repo location | `self_reference` (as `<user>/awesome-<subject>`) |

Also tune these:

- `search.repo_query` — usually `"<subject> in:name"` works. Adjust if the name has hyphens or variants.
- `search.code_queries` — TS/JS import pattern and package.json dep pattern. If the subject has no npm package, clear the array: `code_queries: []`.
- `search.name_pattern` — regex for the signal gate. Match variants the subject might use: `lang[-_]?chain`, `just[-_]?bash`, etc.

After editing, verify the config parses:

```bash
yq -r '.subject.name' awesome.config.yml
# should print the subject name
```

---

## Step 3 — Rewrite `README.md` as a minimal seed

The current `README.md` is for `just-bash`. Replace it with a minimal skeleton for the user's list. Structure:

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

Keep it minimal — the discovery workflow will propose additions, and `insert_entries.py` auto-creates new `## Category` sections as needed. Starting with just `## Official` and letting categories grow organically is the right default.

---

## Step 4 — GitHub setup

Do these via `gh` CLI. The user needs to be authenticated (`gh auth status`).

### 4a. Push to their own repo

If this is a fresh clone, help them push to their GitHub account. Ask for the repo name (default: `awesome-<subject>`).

```bash
gh repo create <user>/<repo> --public --source=. --push
```

### 4b. Add the OpenRouter secret

Ask the user if they have an OpenRouter API key. If not, point them at <https://openrouter.ai/keys> and suggest they add ~$5 in credits (weekly runs cost $0.05–$0.10).

Once they have a key:

```bash
gh secret set OPENROUTER_KEY
```

Interactive prompt — user pastes the key, it doesn't touch shell history.

### 4c. Enable GitHub Actions PR-creation permission

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

### 4d. Set repo description + topics

```bash
gh repo edit <user>/<repo> \
  --description "A curated list of <subject> resources" \
  --add-topic awesome --add-topic awesome-list --add-topic <subject>
```

---

## Step 5 — Do a dry run

Validate the pipeline with no side effects (`DRY_RUN=1` skips the LLM call and the PR).

```bash
gh workflow run discover.yml -f dry_run=true
gh run watch
```

Expected: the job runs to stage 8 and logs "DRY_RUN=1 — done (no changes written)". If any stage errors, read the log and fix before doing a real run.

Common first-run issues:
- `yq: command not found` → only matters on self-hosted runners; GH-hosted Ubuntu runners have it pre-installed. Locally, `brew install yq`.
- Stage 2 filter returns 0 candidates → `search.name_pattern` regex is too tight; loosen it in `awesome.config.yml`.
- `pip install llm llm-openrouter` fails → transient, re-run.

---

## Step 6 — Do a real run

Once the dry run is clean:

```bash
gh workflow run discover.yml
gh run watch
```

Should produce a draft PR with a checklist of candidates (or finish with "nothing new" if zero survive triage — rare but possible for obscure subjects).

If a PR opens: open it in the browser, check some boxes, comment `/apply`. The `apply-discover.yml` workflow should fire, insert the checked entries into `README.md`, and squash-merge automatically.

---

## Step 7 — You're done

- Cron is set for Mondays 09:00 UTC.
- Every week: PR arrives, user checks boxes + `/apply`, entries merge.
- To pause: `touch .discover.disabled && git commit -am "pause discovery" && git push`.
- To tune quality: edit `scripts/checks.md` — add/remove yes/no checks; no code changes needed.
- To change subject later: edit `awesome.config.yml`.
- Costs will show in every PR footer (actual billed cost from OpenRouter, not an estimate).
