# Query

Answer questions by searching and synthesizing knowledge from the wiki.
The wiki is a compiled knowledge base — answers should draw from it, not re-derive from raw sources.

## When to use

- User asks a question about the project's knowledge domain
- User says "what do we know about X", "summarize Y", "compare A vs B"
- User asks for analysis, synthesis, or connections between topics

## Process

### 1. Read the project index

Start with `projects/<project>/index.md` to understand what's available.
Scan page titles and descriptions to identify relevant pages.

### 2. Read relevant pages

Open the wiki pages that seem relevant to the question. Follow `[[wikilinks]]`
to find connected information. Read concept pages, entity pages, and source
summaries as needed.

**Tiered retrieval** — don't read everything:
- **Quick** (simple factual question): index → 1-2 pages → answer
- **Standard** (analytical question): index → 3-5 pages → synthesize → answer
- **Deep** (cross-cutting question): index → all related pages → raw sources if needed → comprehensive answer

### 3. Synthesize the answer

Compose an answer that:
- **Cites sources** — reference wiki pages with `[[wikilinks]]` and original sources
- **Acknowledges uncertainty** — if the wiki has gaps or low-confidence claims, say so
- **Notes contradictions** — if different sources disagree, present both sides
- **Suggests next steps** — if the question reveals a knowledge gap, suggest sources to investigate

### 4. File valuable answers back into the wiki

If the answer is a useful artifact (a comparison, an analysis, a connection that
wasn't previously documented), offer to save it as a new wiki page:

- Comparisons → `wiki/concepts/comparison-<topic>.md`
- Analyses → `wiki/concepts/analysis-<topic>.md`
- New connections → update existing pages with cross-references

This is how explorations compound in the knowledge base.

### 5. Update the log

```markdown
## [YYYY-MM-DD] query | <short question summary>
- Pages consulted: <list>
- Answer filed as page: <page path or "not filed">
```

## Answer formats

Adapt the format to the question type:

| Question Type | Format |
|--------------|--------|
| Factual ("what is X?") | Direct answer with source citations |
| Comparative ("A vs B?") | Markdown table with dimensions |
| Analytical ("why does X?") | Structured narrative with evidence |
| Exploratory ("what do we know about X?") | Summary with links to dive deeper |
| Gap-finding ("what don't we know?") | List of unanswered questions with suggested sources |

## Guidelines

- **Wiki-first** — always check the wiki before falling back to raw sources or general knowledge
- **Don't hallucinate** — if the wiki doesn't have the answer, say so rather than making things up
- **Compound knowledge** — good answers deserve to be wiki pages, not chat ephemera
- **Cross-project awareness** — if the vault has multiple projects, check if other projects have relevant knowledge (read the global `index.md`)
