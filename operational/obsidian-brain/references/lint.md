# Lint

Health-check the wiki. Find and fix structural issues, stale information, and
knowledge gaps. The wiki equivalent of code linting — keeps the knowledge base
healthy as it grows.

## When to use

- User asks for a health check, audit, or maintenance pass
- After a large batch of ingestions
- Periodically (suggest every 10-15 ingested sources)
- User says "lint the wiki", "check for issues", "clean up"

## Checks

Run these checks in order. Report findings as a structured list, then offer to fix.

### 1. Broken links

Scan all wiki pages for `[[wikilinks]]` that point to non-existent pages.

**Report format:**
```markdown
### Broken Links
- `wiki/concepts/auth-flow.md` → [[API Gateway]] (page doesn't exist)
- `wiki/entities/user-service.md` → [[Legacy DB]] (page doesn't exist)
```

**Fix:** Create stub pages for the missing targets, or correct the link if it's a typo.

### 2. Orphan pages

Find wiki pages with zero inbound links — no other page references them.

**Report format:**
```markdown
### Orphan Pages
- `wiki/concepts/caching-strategy.md` — no pages link here
- `wiki/entities/redis-cluster.md` — no pages link here
```

**Fix:** Add `[[wikilinks]]` from related pages, or flag for user review (might be stale).

### 3. Stale claims

Find pages where `updated` frontmatter is significantly older than newer source ingestions
that cover the same topic.

**Report format:**
```markdown
### Potentially Stale
- `wiki/entities/payment-api.md` — last updated 2024-01-15, but `sources/api-v3-spec.md` (ingested 2024-03-20) covers the same entity
```

**Fix:** Re-read the newer source and update the stale page.

### 4. Contradictions

Scan for pages that make conflicting claims about the same topic.

**Report format:**
```markdown
### Contradictions
- `wiki/concepts/auth-flow.md` says "tokens expire in 1h"
- `wiki/sources/security-audit.md` says "tokens expire in 30min"
- Sources: [[original-spec]] vs [[security-audit-2024]]
```

**Fix:** Flag both claims with their sources. Let the user decide which is current.

### 5. Missing pages

Identify concepts or entities that are frequently mentioned across pages but
don't have their own dedicated page.

**Report format:**
```markdown
### Missing Pages (frequently mentioned, no dedicated page)
- "rate limiting" — mentioned in 4 pages, no concept page
- "Auth Service" — mentioned in 3 pages, no entity page
```

**Fix:** Create the missing pages by synthesizing from the pages that mention them.

### 6. Index drift

Check that `index.md` accurately reflects the actual wiki contents:
- Pages listed in index that no longer exist
- Pages in wiki directories not listed in the index
- Metadata (page count, last updated) that's out of date

**Fix:** Update the index to match reality.

### 7. Taxonomy compliance

Check that all pages use tags and entity types from `_meta/taxonomy.md`.
Flag any custom tags that should either be added to taxonomy or normalized.

### 8. Relation consistency

Check the `## Relations` sections across all wiki pages:

**a) Broken relation targets** — does the target page exist?
```markdown
- `wiki/entities/user-service.md` → [calls] [[Payment API]] — target page doesn't exist
```

**b) Invalid relation types** — is the type in `_meta/taxonomy.md`?
```markdown
- `wiki/concepts/auth-flow.md` uses relation type `triggers` — not in taxonomy
```

**c) Missing symmetry** — some relations imply a reverse:
- If A `[contradicts]` B, then B should `[contradicts]` A
- If A `[depends_on]` B, then B should `[used_by]` A
- If A `[part_of]` B, the reverse is informational (no strict requirement)

```markdown
- `wiki/entities/auth-service.md` [contradicts] [[Old Spec]] — but Old Spec has no reverse relation
```

**d) Orphaned relations** — relations pointing to pages that were deleted.

**Fix:** Create missing reverse relations. Fix invalid types. Remove orphaned entries.

## Output

After running all checks, produce a summary:

```markdown
# Lint Report — <project> — YYYY-MM-DD

| Check | Issues Found | Auto-fixable |
|-------|-------------|--------------|
| Broken links | 3 | 2 (stubs) |
| Orphan pages | 1 | 0 (needs review) |
| Stale claims | 2 | 2 |
| Contradictions | 1 | 0 (needs decision) |
| Missing pages | 2 | 2 |
| Index drift | 1 | 1 |
| Taxonomy | 0 | — |
| Relations | 2 | 2 (symmetry) |

**Total: 12 issues, 9 auto-fixable**
```

Ask user: "Want me to fix the auto-fixable issues? The contradictions and orphan
need your input."

After fixing issues (or if no issues found), **regenerate the project context file**.
Read `_meta/skills/context.md` and follow its process to update
`projects/<project>/_context.md`. Lint findings (especially contradictions and
high-fan-out entities) are valuable inputs for the context's "Non-Obvious Patterns" section.

## Log entry

```markdown
## [YYYY-MM-DD] lint | <project>
- Issues found: <N>
- Auto-fixed: <N>
- Needs review: <N>
- Details: [[lint-report-YYYY-MM-DD]]
```
