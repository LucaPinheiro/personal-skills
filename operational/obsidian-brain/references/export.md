# Export

Generate artifacts from the wiki's compiled knowledge. Transform wiki pages into
deliverable formats — reports, slide decks, timelines, glossaries, comparisons.

## When to use

- User asks for a "report", "summary", "presentation", "timeline", "glossary"
- User wants to share knowledge outside Obsidian
- User says "export", "generate", "create a deliverable from the wiki"

## Artifact Types

### Report

A structured document synthesizing knowledge from multiple wiki pages.

```markdown
# <Report Title>
> Generated from [[project]] wiki on YYYY-MM-DD
> Sources: <N pages consulted>

## Executive Summary
<!-- 3-5 sentences -->

## Key Findings
<!-- Bulleted, with [[wikilink]] citations -->

## Details
<!-- Organized by theme/topic -->

## Open Questions
<!-- Knowledge gaps identified -->

## Sources
<!-- List of wiki pages and original sources used -->
```

Save to: `projects/<project>/output/report-<topic>-YYYY-MM-DD.md`

### Slide Deck (Marp)

Generate a Marp-compatible markdown slide deck. Each slide is separated by `---`.

```markdown
---
marp: true
theme: default
paginate: true
---

# <Presentation Title>
### <Project Name>
YYYY-MM-DD

---

## Key Points

- Point 1 — with source citation
- Point 2
- Point 3

---

## <Topic Slide>

<!-- Content from wiki pages -->

---

## Questions & Gaps

- What we don't know yet
- Suggested next investigations
```

Save to: `projects/<project>/output/slides-<topic>-YYYY-MM-DD.md`

### Timeline

Chronological view of events extracted from wiki pages.

```markdown
# Timeline — <Topic>
> Generated from [[project]] wiki on YYYY-MM-DD

| Date | Event | Source |
|------|-------|--------|
| 2024-01-15 | Initial API spec published | [[sources/api-v1-spec]] |
| 2024-02-20 | Auth redesign decision | [[entities/auth-service]] |
| ... | ... | ... |
```

Save to: `projects/<project>/output/timeline-<topic>-YYYY-MM-DD.md`

### Glossary

Terms and definitions extracted from wiki entity and concept pages.

```markdown
# Glossary — <Project>
> Generated from [[project]] wiki on YYYY-MM-DD

| Term | Definition | See Also |
|------|-----------|----------|
| API Gateway | Entry point for all client requests... | [[Auth Service]], [[Rate Limiter]] |
| JWT | JSON Web Token used for... | [[Auth Flow]], [[Token Store]] |
```

Save to: `projects/<project>/output/glossary-YYYY-MM-DD.md`

### Comparison

Side-by-side analysis of two or more topics.

```markdown
# Comparison — <A> vs <B>
> Generated from [[project]] wiki on YYYY-MM-DD

| Dimension | <A> | <B> |
|-----------|-----|-----|
| Purpose | ... | ... |
| Strengths | ... | ... |
| Weaknesses | ... | ... |
| When to use | ... | ... |

## Analysis
<!-- Nuanced discussion beyond the table -->

## Recommendation
<!-- If appropriate -->
```

Save to: `projects/<project>/output/comparison-<topic>-YYYY-MM-DD.md`

## Process

1. **Understand the request** — what type of artifact, what scope, what audience
2. **Identify relevant pages** — read the project index, select pages to draw from
3. **Read the pages** — gather the knowledge to synthesize
4. **Generate the artifact** — write in the appropriate format
5. **Save to `output/`** — all artifacts go in the project's output directory
6. **Update the log:**

```markdown
## [YYYY-MM-DD] export | <project> | <artifact-type>
- Artifact: `output/<filename>`
- Pages consulted: <N>
- Format: report | slides | timeline | glossary | comparison
```

## Guidelines

- **Cite everything** — artifacts inherit the wiki's provenance. Every claim traces to a source.
- **Artifacts are snapshots** — they reflect wiki state at generation time. Note the date prominently.
- **File back into wiki** — if the export process reveals new insights or connections, update the wiki pages too.
- **Audience awareness** — ask who will read the artifact. A technical report for engineers differs from an exec summary.
