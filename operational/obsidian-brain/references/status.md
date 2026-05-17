# Status

Show the current state of the knowledge base — what's been ingested, what changed
recently, and what's pending. The dashboard view of your wiki.

## When to use

- User asks "what's the status?", "what's been ingested?", "show me the state"
- User wants to know what changed since last session
- Before starting work, to understand the current state

## Process

### 1. Read project index and log

Read `projects/<project>/index.md` for the catalog and `projects/<project>/log.md`
for recent activity.

### 2. Scan for pending sources

Check `projects/<project>/raw/` for files that don't appear in the index's source table.
These are sources that have been dropped but not yet ingested.

### 3. Compute stats

Count:
- Total sources ingested
- Total wiki pages (concepts + entities + source summaries)
- Total `[[wikilinks]]` across all pages
- Last activity date
- Pending sources (in `raw/` but not ingested)

### 4. Present the status report

```markdown
# Status — <project> — YYYY-MM-DD

## Overview
- **Sources ingested:** 12
- **Wiki pages:** 34 (8 concepts, 15 entities, 11 source summaries)
- **Cross-references:** ~87 wikilinks
- **Last activity:** 2024-03-20 (ingest)
- **Pending sources:** 3 files in raw/ awaiting ingest

## Pending Sources
| File | Size | Date Added |
|------|------|-----------|
| `raw/api-v4-spec.pdf` | 2.1 MB | 2024-03-21 |
| `raw/meeting-notes-march.md` | 4 KB | 2024-03-22 |
| `raw/competitor-analysis.md` | 12 KB | 2024-03-22 |

## Recent Activity (last 5 entries)
<!-- from log.md -->

## Health Indicators
- Orphan pages: 1
- Broken links: 0
- Pages not updated in 30+ days: 4
```

### 5. Multi-project overview

If run at vault level (not project-specific), show all projects:

```markdown
# Vault Status — YYYY-MM-DD

| Project | Sources | Pages | Pending | Last Activity |
|---------|---------|-------|---------|--------------|
| consulta-saldo | 12 | 34 | 3 | 2024-03-20 |
| desbloquear-cartao | 8 | 22 | 0 | 2024-03-19 |
| consulta-seguro | 5 | 14 | 1 | 2024-03-18 |
```

## Guidelines

- **Quick and non-destructive** — status never modifies files, only reads
- **Suggest next actions** — if there are pending sources, suggest ingest. If there are health issues, suggest lint.
- **Delta awareness** — if the user asks "what changed?", compare current state with the last log entry to show what's new
