# Ingest

Process a new source into the knowledge base. Read the source, extract key information,
and integrate it into the existing wiki — updating entity pages, revising summaries,
noting contradictions, and strengthening the evolving synthesis.

## When to use

- User drops a file in `projects/<project>/raw/` and asks to process it
- User says "ingest this", "process this source", "add this to the wiki"
- User shares a document, article, transcript, or spec to be incorporated

## Process

### 1. Read the source

Read the full source file. If it's long, read in chunks. Note:
- Key claims, facts, data points
- Named entities (people, systems, APIs, concepts)
- Relationships between entities
- Anything that contradicts or extends existing wiki knowledge

### 2. Create a source summary page

Write to `projects/<project>/wiki/sources/<source-name>.md`:

```yaml
---
title: "Source: <original title>"
type: source-summary
tags: [from taxonomy]
source_file: raw/<filename>
ingested: YYYY-MM-DD
confidence: high | medium | low
---
```

Include:
- **TL;DR** — 2-3 sentence summary
- **Key takeaways** — bulleted list of the most important points
- **Entities mentioned** — link to their wiki pages with `[[entity-name]]`
- **Concepts covered** — link to concept pages
- **Open questions** — things the source raises but doesn't answer
- **Contradictions** — if this source disagrees with existing wiki pages, note both claims

### 3. Update or create entity pages

For each significant entity mentioned in the source:

- **Entity page exists?** → Update it with new information, add the source to its references
- **Entity page doesn't exist?** → Create it at `projects/<project>/wiki/entities/<entity>.md`

Entity page template:
```yaml
---
title: <Entity Name>
type: entity
entity_type: <from taxonomy.md>
tags: []
sources: [list of source files]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

When creating or updating entity pages, also extract **typed relations** from the source.
If the source says "the User Service calls the Auth Service", add a `## Relations` section:

```markdown
## Relations
- [calls] [[Auth Service]]
- [depends_on] [[Database Cluster]]
- [implements] [[Business Rule: User Validation]]
```

Use relation types from `_meta/taxonomy.md`. Infer the type from context — pick the most
specific type that fits. Fall back to `related_to` only when the relationship is genuinely unclear.

### 4. Update or create concept pages

Same logic as entities, but for abstract concepts, themes, patterns.
Write to `projects/<project>/wiki/concepts/<concept>.md`.

Concept pages also get a `## Relations` section. Concepts frequently `extends`, `contradicts`,
or `part_of` other concepts.

### 5. Update the project index

Add the new source to the source table in `projects/<project>/index.md`:

```markdown
| [[sources/<name>]] | YYYY-MM-DD | <N pages created/updated> | ingested |
```

Update the wiki pages sections (concepts, entities) with any new pages.

### 6. Append to the project log

```markdown
## [YYYY-MM-DD] ingest | <source title>
- Source: `raw/<filename>`
- Pages created: <list>
- Pages updated: <list>
- Contradictions found: <list or "none">
```

### 7. Append to the global log

```markdown
## [YYYY-MM-DD] ingest | <project> | <source title>
- <one-line summary>
```

### 8. Regenerate project context

After all pages are written, regenerate the project's compass file. Read
`_meta/skills/context.md` and follow its process to update
`projects/<project>/_context.md`. This ensures the context file always reflects
the latest state — new key pages, updated link counts, freshly surfaced contradictions.

## Guidelines

- **Provenance matters** — every claim in the wiki should trace back to a source. Use the `sources` frontmatter field and inline citations like `(from [[sources/source-name]])`.
- **Don't copy, synthesize** — the wiki is not a copy of the source. Extract the signal, discard the noise, and integrate with existing knowledge.
- **Flag confidence** — mark claims as `high` (multiple sources agree), `medium` (single source, plausible), or `low` (speculative, inferred, or contradicted).
- **One source at a time** — process sources individually for better integration. Batch ingest is possible but produces shallower results.
- **Discuss with the user** — after reading the source, briefly share key takeaways before writing pages. The user may want to guide what to emphasize.
