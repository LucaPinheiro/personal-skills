# AGENTS.md Template

This template is read by the obsidian-brain skill and customized during vault setup.
Replace all `{{placeholders}}` with actual values.

---

# {{vault-name}} — Knowledge Base

This vault is an LLM-maintained knowledge base following the LLM Wiki pattern.
The LLM writes and maintains all wiki content. Humans curate sources and direct analysis.

## Structure

```
{{vault-path}}/
├── AGENTS.md          ← you are here
├── _meta/
│   ├── skills/        ← operational skills (read these for workflows)
│   └── taxonomy.md    ← controlled vocabulary for tags and entity types
├── projects/          ← one sub-wiki per project
│   {{projects-tree}}
├── index.md           ← global hub listing all projects
└── log.md             ← global activity timeline
```

## Rules

1. **Never modify files in `raw/`** — sources are immutable, the human's domain
2. **Always update `index.md` and `log.md`** after any operation that changes wiki content
3. **Use `[[wikilinks]]` for internal references** — Obsidian resolves them automatically
4. **Also include standard markdown links** as fallback for non-Obsidian viewers: `[[page]]` and `[page](path/to/page.md)`
5. **Add YAML frontmatter** to every wiki page you create:
   ```yaml
   ---
   title: Page Title
   type: concept | entity | source-summary | comparison | analysis
   tags: [from taxonomy.md]
   sources: [list of source files this page draws from]
   confidence: high | medium | low
   created: YYYY-MM-DD
   updated: YYYY-MM-DD
   ---
   ```
6. **Follow `_meta/taxonomy.md`** for entity types and tags — suggest additions, don't invent silently
7. **Flag contradictions explicitly** — when new information conflicts with existing pages, note both claims with sources
8. **One concept per page** — split pages that cover multiple distinct topics

## Projects

{{projects-table}}

## Operations

This vault has 6 operational skills in `_meta/skills/`. Read the relevant skill file
before performing any operation. Here's when to use each:

| Operation | Skill File | When to Use |
|-----------|-----------|-------------|
| **Ingest** | `_meta/skills/ingest.md` | User drops a new source in `raw/` and asks to process it |
| **Query** | `_meta/skills/query.md` | User asks a question about the knowledge base |
| **Lint** | `_meta/skills/lint.md` | User asks for a health check, or after large ingestion batches |
| **Cross-link** | `_meta/skills/cross-link.md` | After ingest, or when user asks to improve connections |
| **Status** | `_meta/skills/status.md` | User asks what's been ingested, what changed, or what's pending |
| **Export** | `_meta/skills/export.md` | User wants artifacts: reports, slides, timelines, glossaries |

### Workflow: Typical session

1. User drops source(s) in `projects/<name>/raw/`
2. **Ingest** — read and process each source → creates/updates wiki pages
3. **Cross-link** — scan for unlinked mentions → insert `[[wikilinks]]`
4. **Status** — report what was done

### Workflow: Exploration session

1. **Query** — user asks questions → synthesize answers from wiki
2. Good answers get filed back as new wiki pages (they compound the knowledge)
3. **Lint** — periodic health check

### Workflow: Maintenance

1. **Lint** — find issues (broken links, orphans, contradictions, gaps)
2. **Cross-link** — fix missing connections
3. **Status** — confirm improvements

## Domain Context

{{domain-context}}
