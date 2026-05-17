# Cross-Link

Scan the wiki for unlinked mentions and weave them into the knowledge graph
with `[[wikilinks]]`. This is the connective tissue that makes the wiki more
than a collection of isolated pages.

## When to use

- After ingesting new sources (run automatically after ingest)
- User asks to "improve connections", "add links", "connect pages"
- Lint report shows orphan pages
- Periodically, to catch mentions that slipped through

## Process

### 1. Build the page inventory

Collect all wiki page titles and their aliases (from frontmatter `aliases` field, if present).
This is your lookup dictionary — every mention of these names in other pages should be a link.

### 2. Scan for unlinked mentions

For each wiki page, search the body text for mentions of other page titles that
are NOT already wrapped in `[[wikilinks]]` or markdown links.

**Match rules:**
- Case-insensitive matching
- Match both singular and plural forms
- Match common abbreviations (if listed in page aliases)
- Skip matches inside code blocks, frontmatter, and existing links
- Skip self-references (a page mentioning its own title)

### 3. Insert links

For each unlinked mention found:
- Replace the first occurrence in each section with `[[page-name]]`
- Don't over-link — once per section is enough, not every occurrence
- Preserve the original text flow: `the Auth Service handles...` → `the [[Auth Service]] handles...`

### 4. Cross-project linking

If the vault has multiple projects and a mention matches a page in another project:
- Use a project-qualified link: `[[projects/other-project/wiki/entities/shared-entity|Shared Entity]]`
- Only link cross-project when the connection is meaningful, not just incidental name overlap

### 5. Report

```markdown
# Cross-Link Report — <project> — YYYY-MM-DD

## New links inserted: 12

| Page | Links Added | Targets |
|------|------------|---------|
| `concepts/auth-flow.md` | 3 | [[API Gateway]], [[JWT]], [[Token Store]] |
| `entities/user-service.md` | 2 | [[Auth Service]], [[Rate Limiter]] |
| ... | ... | ... |

## Cross-project links: 1
- `concepts/auth-flow.md` → [[projects/shared-infra/wiki/entities/api-gateway|API Gateway]]

## Orphans resolved: 2
- `entities/redis-cluster.md` now linked from `concepts/caching-strategy.md`
```

### 6. Log entry

```markdown
## [YYYY-MM-DD] cross-link | <project>
- Links inserted: <N>
- Cross-project links: <N>
- Orphans resolved: <N>
```

## Guidelines

- **Don't over-link** — one link per page-section is enough. Dense linking reduces readability.
- **Respect context** — only link when the mention is substantively related, not just a passing word.
- **Aliases help** — if a page is frequently mentioned by a different name, add it to the page's `aliases` frontmatter.
- **Run after ingest** — new sources introduce new entities that existing pages might already mention.
