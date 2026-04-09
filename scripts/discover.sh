#!/usr/bin/env bash
#
# Progressive discovery workflow for awesome-just-bash.
#
# Flow (each stage strictly reduces the candidate set before the next):
#   0. Broad discovery   — multiple sources (repo search, code search, npm)
#   1. Cheap metadata    — date, archived, fork, self-reference
#   2. Signal threshold  — must have at least one strong source signal
#   3. Diff readme       — drop anything already listed
#   4. Enrichment        — per-repo API calls for survivors only
#   5. Enriched filters  — README length, dep/import signal
#   6. LLM checklist     — Sonnet answers yes/no questions from scripts/checks.md
#   7. Apply check gates — all checks must pass to include
#   8. Draft PR          — survivors + "considered but skipped" list
#
# Required env: OPENROUTER_KEY, GH_TOKEN
# Optional env:
#   CONFIDENCE_THRESHOLD       (default 0.6)
#   MODEL                      (default openrouter/anthropic/claude-sonnet-4.6)
#   MAX_CANDIDATES_TO_ENRICH   (default 50)   circuit breaker
#   MAX_PROMPT_BYTES           (default 80000) circuit breaker
#   MAX_LLM_CALLS              (default 1)    circuit breaker
#   DRY_RUN                    (default 0)    1 = skip LLM + git + PR
#
# Kill switch: if .discover.disabled exists in the repo root, the script exits
# immediately with a loud notice. Use it to pause the scheduled workflow
# without editing the yaml.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config + circuit breakers
# ---------------------------------------------------------------------------
THRESHOLD="${CONFIDENCE_THRESHOLD:-0.6}"
MODEL="${MODEL:-openrouter/anthropic/claude-sonnet-4.6}"
MAX_CANDIDATES_TO_ENRICH="${MAX_CANDIDATES_TO_ENRICH:-50}"
MAX_PROMPT_BYTES="${MAX_PROMPT_BYTES:-80000}"
MAX_LLM_CALLS="${MAX_LLM_CALLS:-1}"
DRY_RUN="${DRY_RUN:-0}"

RUN_STAMP="$(date -u +%Y-%m-%d-%H%M)"
RUN_DATE="${RUN_STAMP%-*}"
WORK="${RUNNER_TEMP:-/tmp}/discover-$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

README="readme.md"
[ -f README.md ] && README="README.md"

log()  { echo "[discover] $*" >&2; }
fail() { echo "[discover] ABORT: $*" >&2; exit 1; }

llm_calls=0
call_llm() {
  llm_calls=$((llm_calls + 1))
  if [ "$llm_calls" -gt "$MAX_LLM_CALLS" ]; then
    fail "LLM call budget exceeded (MAX_LLM_CALLS=$MAX_LLM_CALLS). This should never happen — check for retry loops."
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN=1 — skipping llm call; writing empty triage result"
    echo '{"entries":[]}'
    return 0
  fi
  llm "$@"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if [ -f .discover.disabled ]; then
  log "Kill switch .discover.disabled is present — aborting cleanly."
  exit 0
fi

[ -f "$README" ]             || fail "$README not found"
[ -f scripts/checks.md ]     || fail "scripts/checks.md not found"
[ -f scripts/triage-prompt.md ] || fail "scripts/triage-prompt.md not found"
command -v jq   >/dev/null   || fail "jq is not installed"
command -v gh   >/dev/null   || fail "gh CLI is not installed"

if [ "$DRY_RUN" != "1" ]; then
  [ -n "${OPENROUTER_KEY:-}" ] || fail "OPENROUTER_KEY is required (set DRY_RUN=1 to skip the LLM call)"
  command -v llm >/dev/null    || fail "llm CLI is not installed"
fi
[ -n "${GH_TOKEN:-}" ] || fail "GH_TOKEN is required"

log "config: threshold=$THRESHOLD model=$MODEL dry_run=$DRY_RUN"
log "budget: max_enrich=$MAX_CANDIDATES_TO_ENRICH max_prompt=$MAX_PROMPT_BYTES max_llm_calls=$MAX_LLM_CALLS"

# ---------------------------------------------------------------------------
# Parse scripts/checks.md -> check names
# ---------------------------------------------------------------------------
mapfile -t CHECK_NAMES < <(
  sed -n '/^## Checks/,$p' scripts/checks.md \
    | tail -n +2 \
    | grep -oE '^[[:space:]]*-[[:space:]]*\*\*[a-z_][a-z0-9_]*\*\*' \
    | sed -E 's/.*\*\*([a-z_][a-z0-9_]*)\*\*.*/\1/'
)
[ "${#CHECK_NAMES[@]}" -gt 0 ] || fail "no checks found in scripts/checks.md"
log "loaded ${#CHECK_NAMES[@]} checks: ${CHECK_NAMES[*]}"

# ---------------------------------------------------------------------------
# Stage 0: Broad discovery
# ---------------------------------------------------------------------------
log "stage 0: broad discovery"

gh search repos "just-bash in:name" --limit 200 \
  --json name,description,stargazersCount,url,createdAt,updatedAt,isFork,isArchived,owner \
  > "$WORK/src-reposearch.json" || echo "[]" > "$WORK/src-reposearch.json"

gh search code 'from "just-bash"' --limit 100 --json repository \
  > "$WORK/src-codeimport.json" 2>/dev/null || echo "[]" > "$WORK/src-codeimport.json"

gh search code '"just-bash":' --extension json --limit 100 --json repository \
  > "$WORK/src-codepkg.json" 2>/dev/null || echo "[]" > "$WORK/src-codepkg.json"

curl -fsS "https://registry.npmjs.org/-/v1/search?text=just-bash&size=250" \
  > "$WORK/src-npm.json" 2>/dev/null || echo '{"objects":[]}' > "$WORK/src-npm.json"

# Normalize each source to a common shape and tag with its origin
jq '[.[] | . + {sources: ["repo-search"]}]' "$WORK/src-reposearch.json" > "$WORK/n-reposearch.json"

jq '[.[] | .repository | {
  name: .name,
  owner: { login: (.nameWithOwner | split("/")[0]) },
  url: ("https://github.com/" + .nameWithOwner),
  description: "",
  sources: ["code-import"]
}]' "$WORK/src-codeimport.json" > "$WORK/n-codeimport.json"

jq '[.[] | .repository | {
  name: .name,
  owner: { login: (.nameWithOwner | split("/")[0]) },
  url: ("https://github.com/" + .nameWithOwner),
  description: "",
  sources: ["code-pkg"]
}]' "$WORK/src-codepkg.json" > "$WORK/n-codepkg.json"

# npm: only keep packages whose description/keywords actually mention just-bash
jq '[
  .objects[].package
  | select((.links.repository // "") | test("github.com"))
  | select(
      ((.description // "") | test("just-bash"; "i"))
      or ((.keywords // []) | any(. | test("just-bash"; "i")))
    )
  | (.links.repository | sub("\\.git$"; "")) as $url
  | ($url | capture("github.com/(?<o>[^/]+)/(?<n>[^/?#]+)")) as $p
  | { name: $p.n, owner: { login: $p.o }, url: $url, description: (.description // ""), sources: ["npm"] }
]' "$WORK/src-npm.json" > "$WORK/n-npm.json"

# Combine + merge sources by repo
jq -s '
  add
  | map(select(.url != null and .name != null and .owner.login != null))
  | group_by((.owner.login | ascii_downcase) + "/" + (.name | ascii_downcase))
  | map(
      reduce .[] as $x ({}; . * $x | .sources = ((.sources // []) + ($x.sources // []) | unique))
    )
' "$WORK/n-reposearch.json" "$WORK/n-codeimport.json" "$WORK/n-codepkg.json" "$WORK/n-npm.json" \
  > "$WORK/s0.json"
log "stage 0: $(jq length "$WORK/s0.json") candidates"

# ---------------------------------------------------------------------------
# Stage 1: Cheap metadata filters
# ---------------------------------------------------------------------------
log "stage 1: date / fork / archived / self-reference"
jq '[.[] | select(
  ((.createdAt // null) == null or (.createdAt >= "2025-12-23T00:00:00Z"))
  and ((.isFork // false) == false)
  and ((.isArchived // false) == false)
  and ((.owner.login + "/" + .name) | ascii_downcase) != "rbbydotdev/awesome-just-bash"
)]' "$WORK/s0.json" > "$WORK/s1.json"
log "stage 1: $(jq length "$WORK/s1.json") candidates"

# ---------------------------------------------------------------------------
# Stage 2: Signal threshold — must have at least one strong source signal
# ---------------------------------------------------------------------------
log "stage 2: strong-signal gate"
jq '[.[] | select(
  (.name | ascii_downcase | test("just[-_]?bash"))
  or (.sources | any(. == "code-pkg" or . == "code-import" or . == "npm"))
)]' "$WORK/s1.json" > "$WORK/s2.json"
log "stage 2: $(jq length "$WORK/s2.json") candidates"

# ---------------------------------------------------------------------------
# Stage 3: Diff against existing readme
# ---------------------------------------------------------------------------
log "stage 3: diff against $README"
grep -oE 'github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+' "$README" \
  | sed 's|github\.com/||; s|\.$||' \
  | sort -u \
  | jq -R . | jq -s 'map(ascii_downcase)' \
  > "$WORK/existing.json"

jq --argjson existing "$(cat "$WORK/existing.json")" '
  map(select(
    (((.owner.login + "/" + .name) | ascii_downcase)) as $key
    | ($existing | index($key)) | not
  ))
' "$WORK/s2.json" > "$WORK/s3.json"
NEW_COUNT=$(jq length "$WORK/s3.json")
log "stage 3: $NEW_COUNT candidates"

if [ "$NEW_COUNT" -eq 0 ]; then
  log "nothing new. done."
  exit 0
fi

# ---- CIRCUIT BREAKER: enrichment cap ----
if [ "$NEW_COUNT" -gt "$MAX_CANDIDATES_TO_ENRICH" ]; then
  log "first 10 candidates for inspection:"
  jq -r '.[0:10][] | "  " + .owner.login + "/" + .name' "$WORK/s3.json" >&2
  fail "stage 3 produced $NEW_COUNT candidates, exceeds MAX_CANDIDATES_TO_ENRICH=$MAX_CANDIDATES_TO_ENRICH. A filter upstream likely regressed. Refine stages 1–2 or raise the limit."
fi

# ---------------------------------------------------------------------------
# Stage 4: Enrichment
# ---------------------------------------------------------------------------
log "stage 4: enriching $NEW_COUNT candidates"
echo "[]" > "$WORK/s4.json"
jq -r '.[] | .owner.login + "/" + .name' "$WORK/s3.json" | while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  log "  $repo"

  meta=$(gh api "repos/$repo" 2>/dev/null || echo "")
  [ -z "$meta" ] && { log "    (api empty, skipping)"; continue; }

  pkg=$(gh api "repos/$repo/contents/package.json" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo "{}")
  has_dep=$(echo "$pkg" | jq -r '((.dependencies // {}) + (.devDependencies // {}) + (.peerDependencies // {})) | has("just-bash")' 2>/dev/null || echo "false")

  readme_text=$(gh api "repos/$repo/readme" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null | head -c 4096 || echo "")
  imports="false"
  if echo "$readme_text" | grep -qE 'from[[:space:]]+"just-bash"|require\("just-bash"\)'; then
    imports="true"
  fi

  jq -n \
    --argjson meta "$meta" \
    --arg repo "$repo" \
    --argjson has_dep "$has_dep" \
    --argjson imports "$imports" \
    --arg readme_excerpt "$readme_text" \
    '{
      repo: $repo,
      url: $meta.html_url,
      description: $meta.description,
      stars: $meta.stargazers_count,
      created_at: $meta.created_at,
      pushed_at: $meta.pushed_at,
      is_fork: $meta.fork,
      is_archived: $meta.archived,
      owner: $meta.owner.login,
      license: ($meta.license.spdx_id // null),
      homepage: $meta.homepage,
      has_just_bash_dep: $has_dep,
      readme_imports_just_bash: $imports,
      readme_excerpt: $readme_excerpt
    }' > "$WORK/entry.json"

  jq --slurpfile new "$WORK/entry.json" '. + $new' "$WORK/s4.json" > "$WORK/s4.tmp"
  mv "$WORK/s4.tmp" "$WORK/s4.json"
done

# ---------------------------------------------------------------------------
# Stage 5: Enriched filters — catch stubs and empties before paying for LLM
# ---------------------------------------------------------------------------
log "stage 5: enriched filters (stub/empty detection)"
jq '[.[] | select(
  (.created_at >= "2025-12-23T00:00:00Z")
  and (.is_archived == false)
  and (.is_fork == false)
  and ((.readme_excerpt | length) >= 200)
)]' "$WORK/s4.json" > "$WORK/s5.json"
S5_COUNT=$(jq length "$WORK/s5.json")
log "stage 5: $S5_COUNT candidates"

if [ "$S5_COUNT" -eq 0 ]; then
  log "all candidates filtered as stubs. done."
  exit 0
fi

# ---------------------------------------------------------------------------
# Stage 6: LLM checklist triage
# ---------------------------------------------------------------------------
log "stage 6: LLM checklist triage"

# Fetch canonical just-bash README for copy detection
gh api repos/vercel-labs/just-bash/readme --jq '.content' 2>/dev/null \
  | base64 -d 2>/dev/null \
  | head -c 3500 > "$WORK/canonical.txt" || echo "" > "$WORK/canonical.txt"

# Build the schema dynamically from check names
{
  printf '{"type":"object","properties":{"entries":{"type":"array","items":{"type":"object","properties":{'
  printf '"repo":{"type":"string"},'
  printf '"checks":{"type":"object","properties":{'
  first=1
  for name in "${CHECK_NAMES[@]}"; do
    [ "$first" -eq 1 ] || printf ','
    printf '"%s":{"type":"boolean"}' "$name"
    first=0
  done
  printf '},"required":['
  first=1
  for name in "${CHECK_NAMES[@]}"; do
    [ "$first" -eq 1 ] || printf ','
    printf '"%s"' "$name"
    first=0
  done
  printf ']},'
  printf '"relevant":{"type":"boolean"},'
  printf '"confidence":{"type":"number"},'
  printf '"category":{"type":"string","enum":["Official","Ports","Filesystem Adapters","Libraries","Integrations","Built With just-bash","Skip"]},'
  printf '"description":{"type":"string"},'
  printf '"reasoning":{"type":"string"}'
  printf '},"required":["repo","checks","relevant","confidence","category","description","reasoning"]}}},'
  printf '"required":["entries"]}'
} > "$WORK/schema.json"
jq empty "$WORK/schema.json" || fail "generated schema is not valid JSON"

# Build the prompt
{
  cat scripts/triage-prompt.md
  echo
  echo "## Verification checklist"
  echo
  echo "Answer each of the following yes/no questions for every candidate. These are hard gates — a candidate that fails any check is rejected regardless of your overall confidence score."
  echo
  cat scripts/checks.md \
    | sed -n '/^## Checks/,$p' \
    | tail -n +2
  echo
  echo "## Canonical just-bash README (for copy detection)"
  echo
  echo '```'
  cat "$WORK/canonical.txt"
  echo
  echo '```'
  echo
  echo "## Current awesome-list readme (for category names and one-liner style)"
  echo
  echo '```markdown'
  cat "$README"
  echo '```'
  echo
  echo "## Candidates"
  echo
  echo '```json'
  cat "$WORK/s5.json"
  echo '```'
} > "$WORK/prompt.md"

# ---- CIRCUIT BREAKER: prompt size ----
PROMPT_SIZE=$(wc -c < "$WORK/prompt.md")
log "prompt size: $PROMPT_SIZE bytes"
if [ "$PROMPT_SIZE" -gt "$MAX_PROMPT_BYTES" ]; then
  fail "prompt size $PROMPT_SIZE exceeds MAX_PROMPT_BYTES=$MAX_PROMPT_BYTES. Refuse to call LLM."
fi

log "calling $MODEL (budget: $MAX_LLM_CALLS call)"
call_llm -m "$MODEL" --schema "$WORK/schema.json" < "$WORK/prompt.md" > "$WORK/triage.json"

# ---------------------------------------------------------------------------
# Stage 7: Apply check gates
# ---------------------------------------------------------------------------
log "stage 7: applying check gates + confidence ≥ $THRESHOLD"

# Build a jq select expression: all checks must be true
CHECK_FILTER=""
for name in "${CHECK_NAMES[@]}"; do
  CHECK_FILTER+=" and .checks.$name"
done

jq "[ .entries[] | select(
  .relevant
  and .confidence >= $THRESHOLD
  and .category != \"Skip\"
  $CHECK_FILTER
) ]" "$WORK/triage.json" > "$WORK/keep.json"
KEEP_COUNT=$(jq length "$WORK/keep.json")
log "stage 7: $KEEP_COUNT candidates survive"

if [ "$KEEP_COUNT" -eq 0 ]; then
  log "no candidates passed all gates. done."
  exit 0
fi

# ---------------------------------------------------------------------------
# Stage 8: Open checklist PR (README is NOT edited yet — user approves first)
# ---------------------------------------------------------------------------
log "stage 8: opening checklist PR"

if [ "$DRY_RUN" = "1" ]; then
  log "DRY_RUN=1 — would open PR with $KEEP_COUNT candidates. Winners:"
  jq -r '.[] | "  " + .repo + " → " + .category + "  (" + (.confidence|tostring) + ")"' "$WORK/keep.json" >&2
  log "DRY_RUN=1 — done (no changes written)"
  exit 0
fi

ORIGINAL_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse HEAD)
BRANCH="discover/$RUN_STAMP"

restore_branch() {
  if [ -n "${ORIGINAL_BRANCH:-}" ] && [ "$(git symbolic-ref --short HEAD 2>/dev/null || true)" != "$ORIGINAL_BRANCH" ]; then
    git checkout --quiet "$ORIGINAL_BRANCH" 2>/dev/null || true
  fi
}
trap 'restore_branch; rm -rf "$WORK"' EXIT

git checkout -b "$BRANCH"

# Commit candidates.json to the branch (source of truth for /apply)
mkdir -p .discover
cp "$WORK/keep.json" .discover/candidates.json
cp "$WORK/triage.json" .discover/triage.json
git add .discover/
git commit -m "[discover] $KEEP_COUNT candidates for review — $RUN_DATE"
git push -u origin "$BRANCH"

# Build PR body with checkboxes
{
  echo "Weekly discovery found **$KEEP_COUNT** candidates that passed all checks."
  echo "Review each one, check the entries you want to include, then comment \`/apply\`."
  echo
  echo "## Candidates"
  echo
  jq -r '.[] | "- [ ] **[" + .repo + "](https://github.com/" + .repo + ")** — " + .category + "\n  - " + .description + "\n  - _Confidence: " + (.confidence | tostring) + " — " + .reasoning + "_"' "$WORK/keep.json"
  echo

  SKIPPED=$(jq --argjson threshold "$THRESHOLD" \
    '[ .entries[] | select((.relevant | not) or .confidence < $threshold or .category == "Skip") ]' \
    "$WORK/triage.json")

  if [ "$(echo "$SKIPPED" | jq 'length')" -gt 0 ]; then
    echo "<details>"
    echo "<summary>Considered but skipped ($(echo "$SKIPPED" | jq 'length'))</summary>"
    echo
    echo "$SKIPPED" | jq -r '.[] | "- **" + .repo + "** (" + .category + ", " + (.confidence | tostring) + ") — " + .reasoning'
    echo
    echo "</details>"
    echo
  fi

  echo "---"
  echo
  echo "Generated by \`.github/workflows/discover.yml\` on $RUN_DATE."
  echo "Check the entries you want, comment \`/apply\`, and the workflow will edit the README and mark this PR as ready."
} > "$WORK/pr-body.md"

gh pr create \
  --draft \
  --title "[discover] $KEEP_COUNT new just-bash project(s) — $RUN_DATE" \
  --body-file "$WORK/pr-body.md"

log "done."
