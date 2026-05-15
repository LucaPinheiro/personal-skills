# Personal Skills

Curated collection of AI coding agent skills for use across projects and environments. Works with Claude Code, opencode, Devin CLI, and any SKILL.md-compatible agent.

## Usage

### With Claude Code plugin system
Add this repo as a plugin source or symlink skills into `~/.claude/skills/`.

### With opencode
Skills with `compatibility: opencode` in frontmatter are auto-loaded.

### Manual (any environment)
Copy the desired skill folder into your project's `.claude/commands/` or equivalent directory.

## Repository Structure

```
coding/                     # Application development skills
  python-hex-clean/         # Python + FastAPI Clean Architecture
  fastapi-patterns/         # Advanced FastAPI patterns
  pydantic-patterns/        # Pydantic v2 patterns
  langgraph-agent/          # LangGraph agent development
  prompt-engineering/       # Anthropic SDK / prompt design
  skill-creator/            # Skill authoring, testing, and optimization
platform-engineering/       # Infrastructure / DevOps skills
  aws-cli/                  # AWS CLI v2 best practices
  docker-compose/           # Docker Compose for local dev
superpowers/                # Workflow and process skills (from Superpowers plugin)
  brainstorming/
  dispatching-parallel-agents/
  executing-plans/
  ...
```

## Skills

### Coding

| Skill | Description |
|-------|-------------|
| [`python-hex-clean`](coding/python-hex-clean/SKILL.md) | Python + FastAPI hexagonal/clean architecture with Google Style Guide |
| [`fastapi-patterns`](coding/fastapi-patterns/SKILL.md) | Advanced FastAPI — DI, middleware, WebSockets, security, testing |
| [`pydantic-patterns`](coding/pydantic-patterns/SKILL.md) | Pydantic v2 — validators, discriminated unions, custom types, serialization |
| [`langgraph-agent`](coding/langgraph-agent/SKILL.md) | LangGraph agents — StateGraph, checkpointing, human-in-the-loop, multi-agent |
| [`prompt-engineering`](coding/prompt-engineering/SKILL.md) | Anthropic SDK — prompt caching, tool use, structured output, batch API |
| [`dockerfile-instructions`](coding/dockerfile-instructions/SKILL.md) | Dockerfiles — multi-stage, BuildKit, multi-arch, distroless, per-language templates |
| [`create-makefiles`](coding/create-makefiles/SKILL.md) | Makefiles — safe defaults, self-documenting help, per-language templates |
| [`skill-creator`](coding/skill-creator/SKILL.md) | Create, test, benchmark, and optimize skills with eval framework |

### Platform Engineering

| Skill | Description |
|-------|-------------|
| [`aws-cli`](platform-engineering/aws-cli/SKILL.md) | AWS CLI v2 — command structure, credentials, JMESPath, pagination |
| [`docker-compose`](platform-engineering/docker-compose/SKILL.md) | Docker Compose — multi-service dev environments, healthchecks, profiles |
| [`github-actions`](platform-engineering/github-actions/SKILL.md) | GitHub Actions — CI/CD, OIDC, supply-chain security, SLSA Build L3, attestations |

### Superpowers (Workflow & Process)

| Skill | Description |
|-------|-------------|
| [`brainstorming`](superpowers/brainstorming/SKILL.md) | Explore intent, requirements and design before implementation |
| [`dispatching-parallel-agents`](superpowers/dispatching-parallel-agents/SKILL.md) | Orchestrate 2+ independent tasks with subagents |
| [`executing-plans`](superpowers/executing-plans/SKILL.md) | Execute implementation plans with review checkpoints |
| [`finishing-a-development-branch`](superpowers/finishing-a-development-branch/SKILL.md) | Guide branch completion — merge, PR, keep, or discard |
| [`receiving-code-review`](superpowers/receiving-code-review/SKILL.md) | Handle code review feedback with technical rigor |
| [`requesting-code-review`](superpowers/requesting-code-review/SKILL.md) | Verify work meets requirements before merging |
| [`subagent-driven-development`](superpowers/subagent-driven-development/SKILL.md) | Execute plans with parallel subagents per batch |
| [`systematic-debugging`](superpowers/systematic-debugging/SKILL.md) | Root cause investigation before proposing fixes |
| [`test-driven-development`](superpowers/test-driven-development/SKILL.md) | RED-GREEN-REFACTOR cycle for features and bugfixes |
| [`using-git-worktrees`](superpowers/using-git-worktrees/SKILL.md) | Isolated feature work with git worktrees |
| [`verification-before-completion`](superpowers/verification-before-completion/SKILL.md) | Evidence-based verification before claiming success |
| [`writing-plans`](superpowers/writing-plans/SKILL.md) | Multi-step task planning with parallel batches |
| [`writing-skills`](superpowers/writing-skills/SKILL.md) | TDD-based skill creation and testing |

## Attribution

- **Superpowers skills**: [Superpowers](https://github.com/obra/superpowers) plugin by Jesse Vincent (BSD-3-Clause)
- **Skill Creator**: [Anthropic Skills](https://github.com/anthropics/skills) (adapted with mandatory research phase and multi-platform support)
- **AWS CLI skill**: [lurodrisilva/personal-skills](https://github.com/lurodrisilva/personal-skills) (BSD-3-Clause)

## License

BSD-3-Clause
