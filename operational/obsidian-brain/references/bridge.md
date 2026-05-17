# Bridge

Connect a code project to the Obsidian vault so the agent working on code can
automatically consult business rules, domain knowledge, and past decisions from
the knowledge base. Bidirectional: code informs the KB, KB informs the code.

## When to use

- User says "connect this project to the vault", "link code to KB", "bridge"
- Setting up a new codebase that has a corresponding vault project
- Agent is working in code and encounters business rules or domain terms it doesn't understand
- Code changes affect business logic and the wiki needs updating

## Setup Process

### 1. Identify the pairing

Ask or detect:
- **Code project path** — the root of the code repository (where AGENTS.md or CLAUDE.md lives)
- **Vault project** — which project in the vault corresponds to this codebase

### 2. Create the bridge file in the code project

Write `.claude/kb-link.md` in the code project root:

```markdown
# Knowledge Base Link

- **Vault**: <absolute-path-to-vault>
- **Project**: <project-name>
- **Context**: <vault-path>/projects/<project>/_context.md
- **Last synced**: YYYY-MM-DD

## How to use this link

When you encounter business rules, domain terms, or ambiguous requirements in this codebase:

1. **Read the context file first** (~200 tokens, fast orientation):
   `<vault-path>/projects/<project>/_context.md`

2. **If more detail is needed**, read specific wiki pages referenced in the context file:
   `<vault-path>/projects/<project>/wiki/`

3. **If code changes affect business logic**, note it for wiki update:
   - What changed in the code
   - Which wiki entity or concept is affected
   - Whether existing business rules still hold

## Key domain pages

<!-- Auto-populated from _context.md's Key Pages section -->
1. [[<vault-path>/projects/<project>/wiki/entities/<page>]] — <summary>
2. ...
```

### 3. Update the code project's AGENTS.md

If the code project has an `AGENTS.md` (or `CLAUDE.md`), add a Knowledge Base section:

```markdown
## Knowledge Base

This project is linked to an Obsidian knowledge base with domain context,
business rules, and architectural decisions.

- **Bridge file**: `.claude/kb-link.md`
- **Quick context**: `<vault-path>/projects/<project>/_context.md`

When encountering business logic, domain terms, or requirements questions,
consult the knowledge base before making assumptions. The context file provides
fast orientation (~200 tokens); follow links to wiki pages for full detail.
```

If no AGENTS.md exists, create a minimal one with just this section.

### 4. Update the vault side

Add a `codebase` field to the vault project's `index.md` frontmatter:

```yaml
---
codebase: <absolute-path-to-code-project>
last_bridge_sync: YYYY-MM-DD
---
```

### 5. Populate code references in wiki pages

For wiki entity and concept pages that directly correspond to code (APIs, services,
data models), add a `## Code References` section:

```markdown
## Code References
- Implementation: `<code-path>/src/services/payment_service.py`
- API routes: `<code-path>/src/routes/payment.py`
- Tests: `<code-path>/tests/test_payment.py`
```

This enables the reverse direction: when the wiki is updated, the agent knows
which code files might be affected.

## Bidirectional Workflows

### Code → KB (agent is coding, needs domain context)

```
1. Agent encounters business logic question in code
2. Read .claude/kb-link.md → get vault path and project
3. Read _context.md → fast orientation (key pages, patterns, contradictions)
4. Read specific wiki pages if needed → full business rules
5. Apply knowledge to code decision
```

### KB → Code (wiki updated, code might be stale)

```
1. Wiki page updated with new business rule or API change
2. Check page's ## Code References section
3. If code references exist → flag files that may need updating
4. Report: "Wiki page [[Payment API]] was updated. Code files that may
   need review: src/services/payment_service.py, src/routes/payment.py"
```

### Code change triggers KB update

```
1. Agent makes significant code change (new endpoint, changed business logic)
2. Check if changed files appear in any wiki page's ## Code References
3. If yes → read the wiki page, compare with code change
4. Offer to update the wiki page with new information
5. If updating, follow the ingest workflow (minus the raw source step)
```

## Bridge Status Report

When asked for bridge status:

```markdown
# Bridge Status — <project> — YYYY-MM-DD

## Link
- Code: <code-path>
- Vault: <vault-path>/projects/<project>
- Last synced: YYYY-MM-DD

## Code References (wiki → code)
| Wiki Page | Code Files | Status |
|-----------|-----------|--------|
| [[Payment API]] | payment_service.py, payment.py | ✅ current |
| [[Auth Flow]] | auth_middleware.py | ⚠️ wiki updated since last code review |

## Potential Drift
- Wiki page [[Rate Limiter]] updated 2024-03-20 but no code reference exists
- Code file `src/services/new_feature.py` (created 2024-03-19) has no wiki entity
```

## Log entry

```markdown
## [YYYY-MM-DD] bridge | <project> | setup
- Code project: <code-path>
- Bridge file: .claude/kb-link.md
- Code references created: <N wiki pages>
```

## Guidelines

- **Context file is the entry point** — the bridge always points to `_context.md` first, never directly to individual wiki pages. This keeps token usage low for quick lookups.
- **Don't over-reference** — only add `## Code References` to wiki pages that have a direct implementation in code. Not every concept page needs a code link.
- **Bridge is a pointer, not a copy** — the bridge file tells the agent WHERE to look, not WHAT the knowledge says. Keep it under 30 lines.
- **Cross-platform** — `.claude/kb-link.md` is read by any agent that reads markdown. The AGENTS.md section uses standard markdown. No agent-specific features required.
