# Context

Generate a compact orientation file (`_context.md`) for a project. This is the
"compass, not encyclopedia" — a 25-35 line file (~1000 tokens) that gives any agent
instant situational awareness without reading the full wiki.

Inspired by Meta's approach: 50+ specialized agents achieved 40% fewer tool calls per task
by reading compact context files instead of exploring codebases from scratch.

## When to use

- **Automatically** after every ingest or lint cycle (triggered by those skills)
- User asks "generate context", "update context", "refresh the compass"
- First time entering a project in a new session — if `_context.md` is stale or missing

## Output location

`projects/<project>/_context.md`

## Template

The context file has exactly 4 sections. Every line must earn its place — no filler,
no boilerplate, no restating obvious information from the index.

```markdown
# <Project Name> — Context
> Auto-generated on YYYY-MM-DD. Do not edit manually — regenerated after each ingest/lint.

## Quick Commands
- Ingest new source: read `_meta/skills/ingest.md`
- Ask a question: read `_meta/skills/query.md`
- Health check: read `_meta/skills/lint.md`
- Connect pages: read `_meta/skills/cross-link.md`

## Key Pages (top 5 by inbound link count)
1. [[wiki/entities/<top-page>]] — <N> inbound links — <one-line summary>
2. [[wiki/concepts/<page>]] — <N> inbound links — <one-line summary>
3. ...

## Non-Obvious Patterns
- <contradiction, gotcha, or domain quirk worth flagging>
- <naming convention or implicit rule only visible from multiple sources>
- <relation cluster: "3 entities all depend_on [[Shared Service]]">

## Cross-References
- Related project: [[projects/<other>/index]] — shares [[<shared entity>]]
- Related project: [[projects/<other>/index]] — overlapping concept: [[<concept>]]
```

## Generation Process

### 1. Read the project state

Read `projects/<project>/index.md` and scan wiki pages to gather:
- Page titles with inbound link counts (count `[[page-name]]` occurrences across all pages)
- Any `[contradicts]` relations from `## Relations` sections
- Recent log entries from `projects/<project>/log.md`

### 2. Rank key pages

Sort wiki pages by inbound link count (descending). Take the top 5.
These are the "hub pages" — the most referenced knowledge in the project.

### 3. Extract non-obvious patterns

Look for:
- **Contradictions**: pages with `[contradicts]` relations → always surface these
- **High-fan-out entities**: pages with 5+ outbound relations → likely critical dependencies
- **Relation clusters**: groups of pages all sharing a common relation target
- **Recent changes**: anything ingested in the last 3 entries that updated 3+ existing pages
- **Low-confidence claims**: pages with `confidence: low` that are frequently referenced

Pick the 3-5 most important patterns. Prioritize contradictions and high-fan-out entities.

### 4. Find cross-project references

Scan other projects' wiki pages for mentions of this project's entities or concepts.
Also check for shared entity names across projects.

### 5. Write `_context.md`

Write the file to `projects/<project>/_context.md`. Overwrite any existing version —
this file is always regenerated, never manually edited.

**Hard constraint: 25-35 lines, ~1000 tokens.** If the project is small (few pages),
the file will be shorter. If the project is large, ruthlessly prioritize — only the
most linked pages and most critical patterns.

### 6. Log entry (only if run standalone)

When triggered manually (not as part of ingest/lint), append:

```markdown
## [YYYY-MM-DD] context | <project>
- Key pages: <top 3 names>
- Patterns flagged: <N>
- Cross-refs found: <N>
```

## Guidelines

- **Regenerate, don't append** — the context file is a snapshot, not a log. Overwrite every time.
- **Prioritize contradictions** — these are the most valuable signals for agents making decisions.
- **Link counts are heuristic** — a page with 12 inbound links is more "central" than one with 2, but context matters. A recently ingested page with 3 links about a critical decision may outrank a 10-link background entity.
- **Don't duplicate the index** — the context file is NOT a smaller index. It highlights what's important and surprising. The index lists everything; the context file curates.
