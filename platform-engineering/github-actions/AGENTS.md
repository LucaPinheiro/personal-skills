<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# github-actions

## Purpose
Skill that guides authoring + reviewing GitHub Actions workflows (`.github/workflows/*.yml`), composite + JavaScript actions (`action.yml`), and anything under `.github/`. Synthesizes the official GitHub Actions reference (workflow syntax, contexts + expressions, workflow commands, dependency caching) with the artifact-attestation security track (build provenance, SBOM, generic attestations, SLSA Build L3, Sigstore policy-controller enforcement) into opinionated rules: floor-level `permissions:`, SHA-pinning third-party actions, OIDC federation instead of long-lived secrets, environment-protected production deploys, script-injection-safe `run:` steps via `env:`, and attested release artifacts.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: github-actions`, `domain: platform-engineering`, `pattern: ci-cd-governance`, `platform: github-actions` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- The six non-negotiables at the top of the skill (floor `permissions:`, SHA-pinning third-party actions, script-injection safety via `env:` bindings, OIDC federation for cloud creds, environment gates on prod deploys, build-provenance attestations on release artifacts) are flag-first rules in any PR review. Do not soften them when editing.
- "MANDATORY WORKFLOW PROLOGUE" ships the canonical workflow header (`name`, scoped `on:` triggers, `permissions: {}`). New examples should start from that prologue.
- This skill is also the canonical reference for the repo's own `.github/workflows/validate-skills.yml` — keep advice consistent with what that workflow already does (pinned `actions/checkout@v4`, `mikefarah/yq@master`, floor `permissions: contents: read`).

### Testing Requirements
- **`scripts/validate-skills.sh` does NOT walk this directory.** After editing, manually verify frontmatter validity, non-empty body, and balanced fenced blocks.
- The skill's own examples must satisfy its own rules — if you add a new workflow snippet, it must pin actions by SHA and start at floor `permissions:`.

### Common Patterns
- "Non-negotiables encoded in this skill" numbered list — mirrors `addons-and-building-blocks`.
- "WHEN TO USE THIS SKILL" matrix opens the body.
- Examples favor `permissions: {}` at workflow level + per-job widening (`permissions: id-token: write` only on the job that needs OIDC).

## Dependencies

### Internal
- `../../README.md` — references this skill in the "Platform Engineering" table.
- `../../scripts/validate-skills.sh` — *currently does not validate this file*; expanding the validator is a tracked follow-up.
- `../../.github/workflows/validate-skills.yml` — the repo's own workflow that this skill's principles apply to.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
