---
name: obsidian-brain
description: >-
  Use when setting up an Obsidian vault as an LLM-maintained knowledge base for a project.
  Scaffolds the full directory structure, generates operational sub-skills (ingest, query, lint,
  cross-link, status, export) inside the vault, and writes an AGENTS.md that teaches any AI
  coding agent how and when to use each operation. Supports creating new vaults or adding
  projects to existing ones. Triggers on — "create a brain", "obsidian wiki", "knowledge base
  for project", "LLM wiki", "vault setup", "brain para projeto", "criar brain", "adicionar
  jornada", "novo projeto no vault", or any request to set up a structured knowledge base
  backed by Obsidian.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: operational
  category: knowledge-management
  pattern: llm-wiki
  tools: obsidian
  inspiration: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
---

# Obsidian Brain — LLM Wiki Setup Skill

Scaffolds an Obsidian vault (or extends an existing one) as a persistent, LLM-maintained
knowledge base following the LLM Wiki pattern. The LLM writes and maintains the wiki — you
curate sources, direct analysis, and ask questions. The tedious bookkeeping (cross-references,
summaries, contradiction tracking, index maintenance) is the LLM's job.

## Architecture

Three layers, always:

| Layer | Owner | Purpose |
|-------|-------|---------|
| **Raw sources** (`raw/`) | Human | Immutable. Articles, PDFs, specs, meeting notes. LLM reads, never modifies. |
| **Wiki** (`wiki/`) | LLM | Compiled knowledge. Summaries, entity pages, concept pages, comparisons. LLM creates, updates, cross-references. |
| **Schema** (`AGENTS.md` + `_meta/`) | Co-evolved | Conventions, taxonomy, sub-skills. Tells the LLM how to operate on this vault. |

## Wizard Flow

When this skill is invoked, gather these inputs before scaffolding:

### Step 1 — Detect context

```
Is there an existing vault?
  → Ask: "What's the path to your Obsidian vault?"
  → Check if AGENTS.md and _meta/ already exist at that path

No vault yet?
  → Ask: "Where should I create the vault? (path)"
```

### Step 2 — Project details

Ask these one at a time:

1. **Project name** — kebab-case identifier (e.g., `consulta-saldo-cartao`)
2. **Domain** — one of:
   - `research` — papers, articles, evolving thesis
   - `business` — meeting notes, decisions, business rules, API specs
   - `personal` — goals, journal, self-improvement
   - `engineering` — codebase docs, architecture decisions, incident reports
3. **Short description** — one line describing the project's purpose

### Step 3 — Scaffold

Generate the full structure. If the vault already exists, only add the new project under
`projects/` and update the global `index.md`. Never overwrite existing files.

## Generated Structure

### New vault (first project)

```
<vault-path>/
├── AGENTS.md                    # Schema — how agents operate on this vault
├── _meta/
│   ├── skills/                  # Operational sub-skills
│   │   ├── ingest.md
│   │   ├── query.md
│   │   ├── lint.md
│   │   ├── cross-link.md
│   │   ├── status.md
│   │   └── export.md
│   └── taxonomy.md              # Controlled vocabulary (tags, entity types)
├── projects/
│   └── <project-name>/
│       ├── raw/                 # Drop sources here
│       │   └── .gitkeep
│       ├── wiki/                # LLM-generated pages
│       │   ├── concepts/        # Concept/topic pages
│       │   ├── entities/        # Entity pages (people, systems, APIs)
│       │   └── sources/         # Source summary pages
│       ├── output/              # Generated artifacts (reports, slides, etc.)
│       │   └── .gitkeep
│       ├── index.md             # Project-level catalog
│       └── log.md               # Project-level activity log
├── index.md                     # Global hub — lists all projects
└── log.md                       # Global activity timeline
```

### Adding to existing vault

Only create:
- `projects/<project-name>/` with full sub-structure
- Update global `index.md` with new project entry
- Append to global `log.md`

## File Templates

### Global `index.md`

```markdown
# Knowledge Base

Central hub for all projects in this vault.

## Projects

| Project | Domain | Description | Pages | Last Updated |
|---------|--------|-------------|-------|--------------|
| [[projects/<name>/index\|<name>]] | <domain> | <description> | 0 | <date> |
```

### Global `log.md`

```markdown
# Activity Log

Append-only record of all operations across the vault.

## [<date>] setup | <project-name>
- Created project structure
- Domain: <domain>
- Description: <description>
```

### Project `index.md`

```markdown
# <Project Name>

> <description>
> Domain: <domain>

## Source Summary

| Source | Date Ingested | Pages Produced | Status |
|--------|--------------|----------------|--------|
<!-- Updated by ingest skill -->

## Wiki Pages

### Concepts
<!-- Auto-populated -->

### Entities
<!-- Auto-populated -->

### Source Summaries
<!-- Auto-populated -->
```

### Project `log.md`

```markdown
# <Project Name> — Activity Log

## [<date>] setup
- Project created
- Domain: <domain>
```

### `_meta/taxonomy.md`

Adapt the initial taxonomy based on domain:

**business:**
```markdown
# Taxonomy

## Entity Types
- `system` — internal systems, APIs, services
- `process` — business processes, workflows, journeys
- `rule` — business rules, validations, constraints
- `stakeholder` — teams, roles, people
- `decision` — architectural or business decisions with rationale

## Tags
- `#status/active` `#status/deprecated` `#status/proposed`
- `#confidence/high` `#confidence/medium` `#confidence/low`
- `#source-type/spec` `#source-type/meeting` `#source-type/code` `#source-type/doc`
```

**research:**
```markdown
# Taxonomy

## Entity Types
- `paper` — academic papers, preprints
- `author` — researchers, labs, institutions
- `method` — techniques, algorithms, approaches
- `dataset` — datasets, benchmarks
- `finding` — key results, claims (with confidence)

## Tags
- `#status/confirmed` `#status/disputed` `#status/replicated`
- `#confidence/high` `#confidence/medium` `#confidence/low`
- `#source-type/paper` `#source-type/article` `#source-type/talk` `#source-type/repo`
```

**engineering:**
```markdown
# Taxonomy

## Entity Types
- `service` — microservices, APIs, modules
- `pattern` — design patterns, architectural decisions
- `incident` — outages, bugs, postmortems
- `dependency` — libraries, frameworks, external services
- `adr` — architecture decision records

## Tags
- `#status/active` `#status/deprecated` `#status/planned`
- `#severity/critical` `#severity/high` `#severity/medium` `#severity/low`
- `#source-type/code` `#source-type/doc` `#source-type/incident` `#source-type/adr`
```

**personal:**
```markdown
# Taxonomy

## Entity Types
- `goal` — objectives, milestones
- `habit` — routines, practices
- `insight` — realizations, connections
- `resource` — books, courses, tools
- `person` — mentors, collaborators

## Tags
- `#area/health` `#area/career` `#area/learning` `#area/relationships`
- `#status/active` `#status/completed` `#status/paused`
- `#source-type/journal` `#source-type/article` `#source-type/book` `#source-type/podcast`
```

## AGENTS.md Generation

Read the template from `references/agents-template.md` and customize it:

1. Replace `{{vault-path}}` with the actual vault path
2. Replace `{{projects-list}}` with the current project table
3. Adapt the "Operations" section emphasis based on domain:
   - **business**: emphasize ingest (specs, meeting notes) and query (business rules lookup)
   - **research**: emphasize ingest (papers) and query (thesis-driven synthesis)
   - **engineering**: emphasize ingest (code docs, ADRs) and lint (consistency checks)
   - **personal**: emphasize ingest (journal, articles) and cross-link (pattern discovery)

## Sub-Skills Installation

Copy each sub-skill template from `references/` into `_meta/skills/` within the vault.
These are **not templates to customize** — they are the actual operational skills that the
agent will read and follow. They work as-is for any domain.

Read each from:
- `references/ingest.md` → `_meta/skills/ingest.md`
- `references/query.md` → `_meta/skills/query.md`
- `references/lint.md` → `_meta/skills/lint.md`
- `references/cross-link.md` → `_meta/skills/cross-link.md`
- `references/status.md` → `_meta/skills/status.md`
- `references/export.md` → `_meta/skills/export.md`

## Post-Setup Checklist

After scaffolding, verify:

- [ ] `AGENTS.md` exists at vault root and references all 6 skills
- [ ] `_meta/skills/` contains all 6 `.md` files
- [ ] `_meta/taxonomy.md` matches the chosen domain
- [ ] `projects/<name>/` has `raw/`, `wiki/` (with subdirs), `output/`, `index.md`, `log.md`
- [ ] Global `index.md` lists the new project
- [ ] Global `log.md` has the setup entry
- [ ] No existing files were overwritten

Then tell the user:

> "Vault configurado. Para começar, drop seus primeiros arquivos em
> `projects/<name>/raw/` e peça para o agent fazer o ingest. O AGENTS.md
> já ensina qualquer agent (Claude Code, Codex, Cursor, Gemini CLI, etc.)
> a operar nesse vault."

## Tips for the User

- **Obsidian Web Clipper**: browser extension that converts articles to markdown — drop into `raw/`
- **Graph View**: use Obsidian's graph view to see connections between pages
- **Dataview plugin**: if the LLM adds YAML frontmatter, Dataview generates dynamic tables
- **Git**: the vault is just markdown files — version control with git for free
- **One source at a time**: for best results, ingest sources individually and stay involved
