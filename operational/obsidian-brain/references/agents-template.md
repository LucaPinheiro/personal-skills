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
│   │   ├── ingest.md, query.md, lint.md, cross-link.md, status.md, export.md
│   │   ├── context.md   ← compass file generator
│   │   └── bridge.md    ← code ↔ KB connector
│   └── taxonomy.md    ← controlled vocabulary for tags, entity types, and relation types
├── projects/          ← one sub-wiki per project
│   └── <project>/
│       ├── _context.md  ← auto-generated compass (25-35 lines, read this FIRST)
│       ├── raw/         ← immutable sources
│       ├── wiki/        ← compiled knowledge (concepts/, entities/, sources/)
│       ├── output/      ← generated artifacts
│       ├── index.md     ← project catalog
│       └── log.md       ← project timeline
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
6. **Follow `_meta/taxonomy.md`** for entity types, tags, and relation types — suggest additions, don't invent silently
7. **Flag contradictions explicitly** — when new information conflicts with existing pages, note both claims with sources and add `[contradicts]` relation
8. **One concept per page** — split pages that cover multiple distinct topics
9. **Read `_context.md` first** — when entering a project for the first time in a session, read the project's `_context.md` before diving into wiki pages (~200 tokens vs reading the full index)
10. **Use typed relations** — every wiki page should have a `## Relations` section with entries like `- [depends_on] [[Target Page]]`. Use relation types from `_meta/taxonomy.md`. This creates a semantic graph, not just a link graph.

## Projects

{{projects-table}}

## Operations

This vault has 8 operational skills in `_meta/skills/`. Read the relevant skill file
before performing any operation. Here's when to use each:

| Operation | Skill File | When to Use |
|-----------|-----------|-------------|
| **Ingest** | `_meta/skills/ingest.md` | User drops a new source in `raw/` and asks to process it |
| **Query** | `_meta/skills/query.md` | User asks a question about the knowledge base |
| **Lint** | `_meta/skills/lint.md` | User asks for a health check, or after large ingestion batches |
| **Cross-link** | `_meta/skills/cross-link.md` | After ingest, or when user asks to improve connections |
| **Status** | `_meta/skills/status.md` | User asks what's been ingested, what changed, or what's pending |
| **Export** | `_meta/skills/export.md` | User wants artifacts: reports, slides, timelines, glossaries |
| **Context** | `_meta/skills/context.md` | Auto-triggered after ingest/lint; or manually to refresh the compass file |
| **Bridge** | `_meta/skills/bridge.md` | Connect a code project to this vault for bidirectional knowledge flow |

### Workflow: Typical session

1. User drops source(s) in `projects/<name>/raw/`
2. **Ingest** — read and process each source → creates/updates wiki pages with typed relations
3. **Cross-link** — scan for unlinked mentions → insert `[[wikilinks]]` and `## Relations`
4. **Context** — auto-regenerates `_context.md` (triggered by ingest)
5. **Status** — report what was done

### Workflow: Exploration session

1. Read `_context.md` first — fast orientation (~200 tokens)
2. **Query** — user asks questions → synthesize answers from wiki
3. Good answers get filed back as new wiki pages (they compound the knowledge)
4. **Lint** — periodic health check

### Workflow: Maintenance

1. **Lint** — find issues (broken links, orphans, contradictions, relation inconsistencies)
2. **Cross-link** — fix missing connections and typed relations
3. **Context** — auto-regenerates after lint
4. **Status** — confirm improvements

### Workflow: Code integration

1. **Bridge** — connect a code project to a vault project (one-time setup)
2. While coding: read `_context.md` → relevant wiki pages for business rules
3. After code changes that affect business logic: update wiki entity pages
4. **Bridge status** — check for drift between code and wiki

## Domain Context

{{domain-context}}
