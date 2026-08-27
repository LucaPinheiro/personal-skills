---
name: graphify
description: 'MUST USE when building, querying, serving, or maintaining a **Graphify codebase knowledge graph** — the `graphifyy` (double-y) PyPI package whose CLI/slash-command is `graphify`, which maps an entire repo (code + docs + PDFs + images + audio/video) into a queryable NetworkX `graph.json` for AI coding assistants. Covers the install gotcha (`uv tool install graphifyy` / `pipx install graphifyy` / `pip install graphifyy` installs a console entry point named `graphify`, NOT `graphifyy`), per-assistant registration (`graphify install`, `graphify claude install`, `graphify cursor install`, `graphify vscode install`, `graphify gemini install`, `graphify copilot install`, `graphify devin install`, `graphify install --platform codex|windows`), the slash command `/graphify .` and its flags (`--update`, `--cluster-only`, `--resolution`, `--no-viz`), graph queries (`/graphify query "what connects auth to database?"`, `/graphify path "A" "B"`, `/graphify explain "Node"`), the three-pass pipeline (Pass 1 local tree-sitter code structure with NO API calls, Pass 2 faster-whisper media transcription, Pass 3 Claude/LLM semantic extraction of docs+media via parallel subagents), the functional module chain `detect()→extract()→build_graph()→cluster()→analyze()→report()→export()` (`detect.py`, `extract.py`, `cluster.py` Leiden community detection, `analyze.py` god-nodes/surprises/questions, `report.py`, `export.py`, `cache.py` SHA256 semantic caching, `security.py`, `benchmark.py`, `serve.py`), the NetworkX node-link `graph.json` schema (nodes `id`/`label`/`source_file`/`source_location`/`file_type`, edges `source`/`target`/`relation` verb phrases like `calls`/`imports`/`uses`/`semantically_similar_to`, `confidence` of `EXTRACTED`(1.0)/`INFERRED`(0.55–0.95)/`AMBIGUOUS`, hyperedges in `G.graph["hyperedges"]`), output artifacts under `graphify-out/` (HTML viz, markdown report, `graph.json`, Obsidian vault, SVG, `converted/` Office/Workspace sidecars, `cache/`), the `.graphifyignore` file (`.gitignore` syntax), 33+ tree-sitter languages (local AST, SQL deterministic table/view/FK/JOIN extraction), Office/PDF/image/video/Google-Workspace extraction with optional extras (`graphifyy[pdf]`, `[office]`, `[video]`, `[neo4j]`, `[all]`), headless CI extraction (`graphify extract ./docs --backend claude|gemini|ollama` with `ANTHROPIC_API_KEY`/`GEMINI_API_KEY`/`GOOGLE_API_KEY`/`OPENAI_API_KEY`/`MOONSHOT_API_KEY`/`DEEPSEEK_API_KEY`/AWS-Bedrock/`OLLAMA_BASE_URL`), PR-impact tooling (`graphify prs`, `graphify prs 42`, `graphify prs --triage`, `graphify hook install` AST-only git hooks + merge driver for `graph.json`), architecture export (`graphify export callflow-html`), the MCP stdio server (`python -m graphify.serve graphify-out/graph.json` exposing `query_graph`/`get_node`/`get_neighbors`/`shortest_path`/`list_prs`/`get_pr_impact`/`triage_prs`), the team workflow (commit `graphify-out/` so everyone reads the graph without re-extraction), token economics (~71.5× fewer tokens/query vs raw files on large corpora), `ProcessPoolExecutor` parallel code extraction, query logging at `~/.cache/graphify-queries.log` (disable `GRAPHIFY_QUERY_LOG_DISABLE=1`), and the **companion Docker MCP Toolkit SQLite server** (`docker mcp profile server add default --server catalog://mcp/docker-mcp-catalog/SQLite`, `mcp/sqlite` image, `mcp-sqlite` named volume mounted at `/mcp`, db at `/mcp/db.sqlite`, 6 tools `read_query`/`write_query`/`create_table`/`list_tables`/`describe_table`/`append_insight`) used alongside Graphify for persisting query insights — distinct from Graphify''s own storage (Graphify has NO SQL database; its store is the NetworkX `graph.json`). Triggers on phrases — "graphify", "/graphify", "graphify this repo", "build a knowledge graph of the codebase", "map this codebase", "codebase knowledge graph", "graph my code", "query the code graph", "what connects X to Y in the code", "shortest path between two symbols", "god nodes", "PR impact analysis", "graphify query", "graphify path", "graphify explain", "graphify extract", "graphify export callflow", "graphify prs", "graphify serve / mcp". Triggers on file patterns — `.graphifyignore`, `graphify-out/` directory, `graphify-out/graph.json`, a NetworkX node-link `graph.json`, `pyproject.toml`/lockfile referencing the `graphifyy` package, `graphify install` config blocks injected into `CLAUDE.md` / `.cursor/rules/` / `AGENTS.md`. Authored as a working playbook — emphasizes local-first code extraction (no API cost, no telemetry), committing the graph to git, incremental SHA256-hashed re-runs, confidence-aware reading of edges, and never conflating Graphify''s NetworkX store with the separate Docker SQLite MCP server.'
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: ai
  tool: graphify
  package: graphifyy
  category: codebase-knowledge-graph
  runtime: cli + mcp-stdio
  storage: networkx-graph-json
  extraction: tree-sitter + llm
---

# Graphify — Codebase Knowledge Graph for AI Coding Assistants

Graphify maps an entire corpus — source code, documentation, PDFs, images, audio, and video — into a single queryable **knowledge graph** that an AI coding assistant queries instead of re-reading raw files. Code structure is parsed **locally** with tree-sitter (no API calls, no token cost); documentation and media are sent to a configured LLM for semantic extraction. The output is a NetworkX node-link `graph.json` plus an HTML visualization and a markdown report, all written under `graphify-out/`. On large mixed corpora a query against the graph uses on the order of **71.5× fewer tokens** than asking the assistant to re-read the files.

The package on PyPI is **`graphifyy`** (double-y, requires Python ≥ 3.10), but the console command and slash command it installs are both spelled **`graphify`**. This naming split is the single most common install mistake — see rule 1.

## Non-negotiables

1. **Install `graphifyy`, run `graphify`.** The PyPI distribution name is `graphifyy` (double-y); the entry-point binary and the IDE slash command are both spelled `graphify`. `pip install graphify` installs the wrong/nonexistent package. Always:
   ```bash
   uv tool install graphifyy      # recommended
   # or: pipx install graphifyy
   # or: pip install graphifyy
   ```
2. **Code extraction is local and free.** Pass 1 uses tree-sitter only — classes, functions, imports, call graphs, inline comments, and (for SQL) tables/views/foreign-keys/JOINs are extracted with zero API calls. Only docs, PDFs, images, and media transcripts go to an LLM (Pass 3). Never claim Graphify "sends your code to an API" — it does not.
3. **Commit `graphify-out/` to git.** The graph is the shared artifact: teammates `git pull` and the assistant reads `graph.json` immediately, with no re-extraction. Treat `graphify-out/graph.json` as a first-class, reviewable file. Install the merge driver (`graphify hook install`) so parallel commits don't leave conflict markers in `graph.json`.
4. **Re-runs are incremental — rely on the hash, don't force full rebuilds.** `cache.py` fingerprints every file with SHA256; unchanged files are skipped entirely. Use `/graphify . --update` (or just re-run `/graphify .`) after edits. Do **not** delete `graphify-out/cache/` "to be safe" — that throws away the incremental cache and forces a full, slow, billable re-extraction of docs/media.
5. **Read edge `confidence` before trusting a relationship.** Edges are tagged `EXTRACTED` (directly observed: imports, direct calls — confidence 1.0), `INFERRED` (deduced, 0.55–0.95), or `AMBIGUOUS` (flagged for human review). Architectural conclusions must cite `EXTRACTED`/high-`INFERRED` edges; never present an `AMBIGUOUS` edge as fact.
6. **Use a `.graphifyignore` file** (`.gitignore` syntax) to keep `node_modules/`, build output, generated code, and vendored trees out of the graph. An un-ignored `dist/` or `node_modules/` bloats the graph and buries the real god nodes.
7. **Graphify has no SQL database.** Its only store is the NetworkX `graph.json` (plus cache/converted sidecars under `graphify-out/`). If you need a SQLite-backed store for query insights, that is the **separate** Docker MCP Toolkit SQLite server — keep the two mentally distinct (see "Companion: Docker MCP SQLite").
8. **Local-first, no telemetry.** Graphify ships no usage tracking. Query logging is local-only at `~/.cache/graphify-queries.log`; disable it with `GRAPHIFY_QUERY_LOG_DISABLE=1`. Don't add external reporting.

## When to use this skill

| Scenario | Use this skill? |
|----------|-----------------|
| Building a knowledge graph of a repo with `/graphify .` | **Yes** |
| Querying an existing graph (`/graphify query`, `path`, `explain`) | **Yes** |
| Onboarding to / understanding a large unfamiliar codebase | **Yes** |
| PR impact analysis (`graphify prs`, `prs --triage`) | **Yes** |
| Serving the graph to an assistant over MCP (`python -m graphify.serve`) | **Yes** |
| Headless extraction in CI (`graphify extract … --backend …`) | **Yes** |
| Registering Graphify with Claude Code / Cursor / Copilot / Gemini / Codex | **Yes** |
| Debugging install ("command not found: graphify" after `pip install graphify`) | **Yes** — wrong package name |
| Architecture/call-flow export (`graphify export callflow-html`) | **Yes** |
| Standing up the Docker MCP **SQLite** server next to Graphify | **Yes** — companion section |
| Writing a brand-new tree-sitter extractor / contributing to Graphify internals | **Partial** — pipeline map below; defer parser specifics to the repo |
| A generic graph DB (Neo4j/Neptune) unrelated to Graphify | **No** — wrong tool (Graphify can *export* to Neo4j via `graphifyy[neo4j]`, but it is not a graph-DB skill) |
| RAG/vector-embedding pipelines | **No** — Graphify uses graph structure as the similarity signal, not a vector index |

## Install & register

```bash
# 1. Install the package (entry point = `graphify`)
uv tool install graphifyy
# optional capability extras (install only what you need):
uv tool install "graphifyy[pdf]"      # PDF text extraction
uv tool install "graphifyy[office]"   # .docx / .xlsx
uv tool install "graphifyy[video]"    # audio/video transcription (faster-whisper)
uv tool install "graphifyy[neo4j]"    # Neo4j export
uv tool install "graphifyy[all]"      # everything

# 2. Register the /graphify command with your assistant(s)
graphify install                      # auto-detect
graphify claude install               # Claude Code
graphify cursor install               # Cursor
graphify vscode install               # VS Code
graphify gemini install               # Gemini CLI
graphify copilot install              # GitHub Copilot
graphify devin install                # Devin
graphify install --platform codex     # Codex
graphify install --platform windows   # Windows-specific
```

Registration writes platform-specific config (e.g. into `CLAUDE.md`, `.cursor/rules/`, `AGENTS.md`) so `/graphify` is always available in that assistant. For IDE `/graphify` commands the model API key comes from your IDE session — no separate key needed.

## Core workflow — build, then query

```bash
# Build / update the graph for the current directory
/graphify .                           # full build (writes graphify-out/)
/graphify ./docs --update             # incremental update of a subtree
/graphify . --cluster-only --resolution 1.5   # re-cluster only, tune community size
/graphify . --no-viz                  # skip the HTML visualization

# Query the built graph (cheap — no re-reading source)
/graphify query "what connects auth to database?"
/graphify path "UserService" "DatabasePool"     # shortest path between two nodes
/graphify explain "RateLimiter"                  # neighborhood + role of one node
```

After `/graphify .`, read `graphify-out/report.md` first: it surfaces **god nodes** (most-connected concepts), **surprising connections**, and **suggested questions**. Open `graphify-out/*.html` for click-to-explore navigation.

## The three-pass pipeline

Graphify processes a corpus in three passes; each stage is modular with no shared state (plain Python dicts + NetworkX graphs):

- **Pass 1 — Code structure (local, no API):** tree-sitter parses 33+ languages, extracting classes, functions, imports, call graphs, and inline comments/docstrings (the latter become separate semantic nodes). SQL gets deterministic extraction of tables, views, foreign keys, and JOIN relationships. Code files **bypass** the LLM. `ProcessPoolExecutor` parallelizes this across cores (bypassing the GIL).
- **Pass 2 — Media transcription (local):** audio/video are transcribed with faster-whisper, seeded with the current top god nodes so transcripts stay on-domain. Transcripts are cached.
- **Pass 3 — Semantic extraction (LLM):** docs, PDFs, images, and transcripts are analyzed by parallel Claude/LLM subagents; each returns a JSON fragment of nodes/edges/group relationships that merge into the final graph. Office and Google-Workspace files are first converted to Markdown sidecars under `graphify-out/converted/`.

Community structure is then computed by the **Leiden algorithm** over the extracted semantic edges (notably `semantically_similar_to`) — the graph structure *is* the similarity signal, so there is no separate vector-embedding index.

## Module map (functional pipeline)

```
detect() → extract() → build_graph() → cluster() → analyze() → report() → export()
```

| Module | Responsibility |
|--------|----------------|
| `detect.py` | `collect_files(root)` — filter/collect candidate paths (honors `.graphifyignore`) |
| `extract.py` | Per-file extraction dispatcher → extraction dicts (tree-sitter walk: parse → walk nodes → collect nodes+edges) |
| `build_graph()` | Merge extraction dicts into a NetworkX graph |
| `cluster.py` | Leiden community detection; annotate nodes with community attributes |
| `analyze.py` | Compute god nodes, surprising connections, suggested questions |
| `report.py` | Render markdown report from graph + analysis |
| `export.py` | Emit `graph.json`, HTML, SVG, Obsidian vault, (optional) Neo4j |
| `cache.py` | `check_semantic_cache()` / `save_semantic_cache()` — SHA256 incremental cache |
| `security.py` | Input validation: HTTP(S)-only URLs, redirect blocking, size/timeout caps, paths confined to `graphify-out/`, label sanitization (strip control chars, 256-char cap, HTML-escape) |
| `benchmark.py` | Token-usage comparison: full corpus vs subgraph query |
| `serve.py` | MCP stdio server over a `graph.json` |

## Graph format (`graphify-out/graph.json`)

NetworkX node-link format. Schema:

```json
{
  "nodes": [
    { "id": "unique_string", "label": "human name",
      "source_file": "path/to/file", "source_location": "L42",
      "file_type": "py" }
  ],
  "edges": [
    { "source": "id_a", "target": "id_b",
      "relation": "calls",
      "confidence": "EXTRACTED" }
  ]
}
```

- `relation` is a verb phrase: `calls`, `imports`, `uses`, `semantically_similar_to`, etc.
- `confidence` ∈ `EXTRACTED` (1.0) | `INFERRED` (0.55–0.95) | `AMBIGUOUS`.
- Hyperedges (relationships among 3+ nodes) live in `G.graph["hyperedges"]`, not in the `edges` array.

## PR impact & git integration

```bash
graphify prs                # analyze open PRs against the graph
graphify prs 42             # impact analysis for PR #42
graphify prs --triage       # rank PRs by graph blast-radius
graphify hook install       # git hooks: AST-only auto-rebuild on commit (no API cost)
                            # + merge driver so graph.json never gets conflict markers
```

Git hooks rebuild only the local code structure (Pass 1) on commit, so they cost nothing and keep the committed graph current.

## Headless extraction (CI)

For non-interactive environments, `graphify extract` runs Pass 3 against an explicit backend. Code (Pass 1) remains local regardless of backend.

```bash
graphify extract ./docs --backend claude
graphify extract ./docs --backend gemini
graphify extract ./docs --backend ollama
```

API keys by backend (env vars):

| Backend | Env var |
|---------|---------|
| Claude | `ANTHROPIC_API_KEY` |
| Gemini | `GEMINI_API_KEY` / `GOOGLE_API_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Kimi Code | `MOONSHOT_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| AWS Bedrock | AWS credentials (IAM-based, no API key) |
| Ollama (local) | `OLLAMA_BASE_URL` |

## Serve the graph over MCP

Expose a built graph as MCP tools an assistant can call:

```bash
python -m graphify.serve graphify-out/graph.json
```

Tools provided: `query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `list_prs`, `get_pr_impact`, `triage_prs`.

Architecture/call-flow export for humans:

```bash
graphify export callflow-html
```

## Companion: Docker MCP SQLite server

This is a **separate** server (Docker MCP Toolkit, `mcp/sqlite` image) often run *alongside* Graphify to persist query insights/notes in SQLite. It is **not** Graphify's own store — Graphify's store is the NetworkX `graph.json` (rule 7). Use the `mcp/sqlite` image, not the broken `mcp/sqlite-mcp-server`. Requires Docker Desktop with a working socket at `/var/run/docker.sock`.

```bash
# Add the SQLite server to the default MCP profile and pull the image
docker mcp profile server add default --server catalog://mcp/docker-mcp-catalog/SQLite
docker pull mcp/sqlite:latest

# Verify
docker mcp profile show default | grep -E '^[[:space:]]+name:'
docker mcp tools count

# The 6 SQLite tools
docker mcp tools call list_tables
docker mcp tools call create_table query='CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY, body TEXT)'
docker mcp tools call write_query  query="INSERT INTO notes(body) VALUES('graph insight')"
docker mcp tools call read_query   query='SELECT * FROM notes ORDER BY id'
docker mcp tools call describe_table table_name=notes
docker mcp tools call append_insight insight='3 rows inserted'

# Connect MCP clients
docker mcp client connect claude-code
docker mcp client connect cursor
docker mcp client connect vscode
docker mcp client connect claude-desktop
```

Storage persists in a Docker named volume:

| Component | Value |
|-----------|-------|
| Volume name | `mcp-sqlite` |
| Container mount path | `/mcp` |
| Database file | `/mcp/db.sqlite` |

```bash
# Inspect the persisted DB
docker volume inspect mcp-sqlite
docker run --rm -v mcp-sqlite:/mcp:ro alpine ls -la /mcp
docker run --rm -v mcp-sqlite:/mcp:ro keinos/sqlite3 sqlite3 /mcp/db.sqlite '.schema'

# Cleanup
docker mcp profile server remove default SQLite
docker volume rm mcp-sqlite
docker rmi mcp/sqlite:latest
```

The 6 tools exposed: `read_query`, `write_query`, `create_table`, `list_tables`, `describe_table`, `append_insight`.

## What gets extracted

- **Code (33+ languages, tree-sitter, local):** Python, TypeScript, JavaScript, Go, Rust, Java, C/C++, Ruby, C#, Kotlin, PHP, Swift, Lua, Zig, PowerShell, Elixir, Objective-C, Julia, Vue, Svelte, Astro, Groovy, Dart, SQL, Fortran, Pascal, Shell/Bash, JSON, and more.
- **Docs:** Markdown, HTML, RST, YAML, plaintext.
- **Office (`[office]` extra):** DOCX, XLSX.
- **Media (`[video]`/`[pdf]` extras):** PDF, PNG/JPG/WebP/GIF, MP4/MOV, MP3/WAV, YouTube URLs.
- **Google Workspace:** `.gdoc`, `.gsheet`, `.gslides` (converted to Markdown sidecars).

## Output artifacts (`graphify-out/`)

| Artifact | Purpose |
|----------|---------|
| `graph.json` | NetworkX node-link graph — the queryable store (commit this) |
| `*.html` | Interactive click-to-explore visualization |
| `report.md` | God nodes, surprising connections, suggested questions |
| `*.svg` | Static graph render |
| Obsidian vault | Markdown-linked notes view |
| `converted/` | Office / Workspace → Markdown sidecars |
| `cache/` | SHA256 incremental cache — do **not** delete casually |

## Anti-patterns

| Anti-pattern | Why it's wrong | Do instead |
|---|---|---|
| `pip install graphify` | Wrong/nonexistent package → "command not found" | `uv tool install graphifyy` (double-y); the command is still `graphify` |
| `.gitignore`-ing `graphify-out/` | Teammates must re-extract; defeats the shared-graph workflow | Commit `graphify-out/`; run `graphify hook install` for the merge driver |
| Deleting `graphify-out/cache/` before a re-run | Forces a full, billable re-extraction of docs/media | Re-run `/graphify .` / `--update`; trust SHA256 incrementality |
| Treating an `AMBIGUOUS` edge as fact | Confidence tiers exist precisely to flag uncertainty | Cite `EXTRACTED`/high-`INFERRED` edges; verify `AMBIGUOUS` against source |
| Re-reading raw files when a graph exists | Wastes ~70× the tokens on large corpora | `/graphify query …`, `path`, `explain`, or the MCP `query_graph` tool |
| Indexing `node_modules/`, `dist/`, generated code | Bloats the graph, hides real god nodes | Add a `.graphifyignore` (`.gitignore` syntax) |
| Conflating Graphify storage with the Docker SQLite MCP server | Graphify has no SQL DB; its store is `graph.json` | Keep the NetworkX graph and the optional `mcp/sqlite` server separate |
| Assuming code is sent to an LLM | Code is tree-sitter-parsed locally (no API/token cost) | Reserve LLM/API keys for docs+media (Pass 3 / `graphify extract`) |
| Using `mcp/sqlite-mcp-server` image | That image is broken | Use `mcp/sqlite:latest` |

## Verification checklist

- [ ] Installed the **`graphifyy`** package; `graphify --help` resolves (command is `graphify`).
- [ ] Registered with the target assistant (`graphify <assistant> install`); `/graphify` is available.
- [ ] `.graphifyignore` excludes vendored/build/generated trees.
- [ ] `/graphify .` completed; `graphify-out/graph.json`, `report.md`, and HTML exist.
- [ ] `graphify-out/` is committed to git; `graphify hook install` ran (merge driver active).
- [ ] Queries answered from the graph (`/graphify query|path|explain`) — not by re-reading source.
- [ ] Any architectural claim cites `EXTRACTED`/high-`INFERRED` edges, not `AMBIGUOUS` ones.
- [ ] For headless/CI: correct `--backend` and matching API-key env var set; code stays local.
- [ ] If serving over MCP: `python -m graphify.serve graphify-out/graph.json` exposes the 7 graph tools.
- [ ] If using the Docker SQLite companion: `mcp/sqlite` image (not the broken one), `mcp-sqlite` volume at `/mcp/db.sqlite`, treated as separate from `graph.json`.
