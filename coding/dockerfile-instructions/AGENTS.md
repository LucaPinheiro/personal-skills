<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# dockerfile-instructions

## Purpose
Skill that guides authoring and reviewing `Dockerfile`, `Containerfile`, and `*.Dockerfile` files. Synthesizes the official Docker docs (multi-stage builds, BuildKit, buildx) with deep-dive material from iximiuz Labs, Blacksmith, and OneUptime. Covers BuildKit prerequisites, multi-stage builds, layer-order + cache-mount + bind-mount + secret-mount + cache-backend optimization, multi-arch builds (`buildx`, QEMU, `TARGETPLATFORM`, manifest lists), per-language templates (Go, Node/TS, Python, .NET, Rust, Java), `.dockerignore`, non-root `USER`, `HEALTHCHECK`, pinned base images, and CI patterns.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: dockerfile-instructions`, `domain: build-tooling`, `pattern: container-image-build` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only.
- Skill is opinionated: every Dockerfile authored under it MUST be multi-stage, MUST ship a `.dockerignore`, and MUST target BuildKit. Do not weaken these positions when editing — call out the alternative tools (`ko`, `jib`, `pack`, `nixpacks`, `dotnet publish /t:PublishContainer`) instead.
- The `# syntax=docker/dockerfile:1.9` directive is required on **line 1** of every example — without it, `--mount=type=cache` parses as a comment.

### Testing Requirements
- After editing, run `./scripts/validate-skills.sh` from the repo root.
- Pay particular attention to fenced-block balance — this skill ships many example Dockerfiles in fenced blocks, and CI fails on a single unclosed ` ``` `.

### Common Patterns
- "WHEN TO USE THIS SKILL" + "When NOT to use a custom Dockerfile" twin matrix.
- Per-language templates section uses one fenced ` ```dockerfile ` block per language.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Coding" table.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
