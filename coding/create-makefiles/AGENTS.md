<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-25 | Updated: 2026-04-25 -->

# create-makefiles

## Purpose
Skill that guides authoring and reviewing GNU Make `Makefile`, `GNUmakefile`, and `*.mk` files. Encodes safe shell defaults, self-documenting help targets, variable flavors, pattern rules, automatic variables, phony targets, parallel execution, portability traps, and per-language templates (Go, Node, Python, .NET, C/C++). Frames Make as a **unified task-runner** wrapping native tools (`go`, `cargo`, `npm`, `dotnet`, `pytest`, `docker`), never replacing them.

## Key Files
| File | Description |
|------|-------------|
| `SKILL.md` | The skill definition — `name: create-makefiles`, `domain: build-tooling`, `pattern: make-task-runner` |

## Subdirectories
None.

## For AI Agents

### Working In This Directory
- Edit `SKILL.md` only. No code, no tests, no other artifacts belong here.
- `name: create-makefiles` matches the directory name — keep them in sync if either is renamed (also update `README.md`).
- The skill's `description:` field is what Claude Code / opencode uses for auto-detection. Adding a new trigger phrase (e.g. "scaffold a Justfile") should be reflected in the description's trigger list.

### Testing Requirements
- After editing, run `./scripts/validate-skills.sh` from the repo root.
- Per-file checks: valid YAML frontmatter, all required fields present, non-empty `metadata` map, non-empty body, balanced fenced code blocks.

### Common Patterns
- The "NON-NEGOTIABLE PROLOGUE" section ships the canonical Makefile header (`SHELL`, `.SHELLFLAGS`, `.DELETE_ON_ERROR`, `MAKEFLAGS`, `.DEFAULT_GOAL`) — every Makefile authored under this skill starts with that prologue.
- "When NOT to use" matrix appears immediately after the trigger matrix — keep this contrast pattern when extending.

## Dependencies

### Internal
- `../../scripts/validate-skills.sh` — enforces frontmatter + body + fenced-block contract.
- `../../README.md` — references this skill in the "Coding" table.

### External
None at runtime — this is documentation, not code.

<!-- MANUAL: -->
