---
name: create-makefiles
description: MUST USE when creating, reviewing, or modifying a Makefile, GNUmakefile, or *.mk file. Use when the user asks to "add a Makefile", "create a Makefile", "set up make targets", "add build automation", "make target", "scaffold make", or wraps multi-tool workflows (build + test + lint + docker + migrations) behind a unified task-runner interface. Covers safe shell defaults, self-documenting help targets, variable flavors, pattern rules, automatic variables, phony targets, parallel execution, portability, and per-language templates (Go, Node, Python, .NET, C/C++). Does NOT replace native build tools — wraps them.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: build-tooling
  pattern: make-task-runner
---

# Makefile Authoring Skill — GNU Make Best Practices

You are a build-automation expert authoring Makefiles that are **safe, self-documenting, portable, and fast**. This skill synthesizes the GNU Make Manual into opinionated rules you apply every time a Makefile is created or edited. Makefiles authored by this skill act as a **unified task-runner** on top of native tools (`go`, `cargo`, `npm`, `dotnet`, `pytest`, `docker`, `kubectl`), never as a replacement for them.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| User asks to "add/create/scaffold a Makefile" | **Yes** |
| User asks for a unified task-runner across build + test + lint + docker + migrations | **Yes** |
| Modifying an existing `Makefile`, `GNUmakefile`, or `*.mk` file | **Yes** |
| CI/CD wrapper where every job calls `make <target>` | **Yes** |
| Language skill (e.g. `golang-hex-clean`) is active and user wants build automation | **Yes** — wrap the language-native commands, do not replicate its rules |
| Single-file script with no build step | **No** — just document the command |
| Project already has a superior native runner and no orchestration need | **No** — don't add a Makefile for its own sake |

### When NOT to Use Make

- **Single-file scripts** — no build step, no orchestration value.
- **Language with a sufficient native runner and no cross-tool glue** — Go's `go`, Rust's `cargo`, or `npm`/`pnpm` scripts already cover it. Only introduce Make when you are stitching **multiple tools** (build + lint + docker + db migrations + infra) under one interface.
- **Windows-primary projects without a POSIX shell** — Make assumes `/bin/sh` semantics. Use `just`, `taskfile.dev`, or `psake` instead.
- **Workflow is trivially linear (one command)** — just document the command. Don't wrap `npm test` in a one-line Make target.

---

## NON-NEGOTIABLE PROLOGUE

Every Makefile this skill authors MUST begin with this prologue, adjusted only as noted:

```make
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.DEFAULT_GOAL := help
```

### Why each line matters

| Line | Reason |
|------|--------|
| `SHELL := /usr/bin/env bash` | Forces bash. Default `/bin/sh` varies by OS (dash on Debian, bash-as-sh on macOS) — kills portability of recipes. |
| `.SHELLFLAGS := -eu -o pipefail -c` | `-e` exits on any failed command, `-u` errors on unset variables, `-o pipefail` propagates failures through pipes. Without these, `foo \| bar` succeeds even if `foo` crashes. |
| `.DELETE_ON_ERROR:` | If a recipe fails mid-way, delete the partially-written target. Prevents "success on rebuild because the broken file is newer than its prereqs." |
| `MAKEFLAGS += --warn-undefined-variables` | Typos in `$(VAR)` become warnings instead of silently expanding to empty string. |
| `MAKEFLAGS += --no-builtin-rules` | Disables GNU Make's built-in implicit rules (Fortran, Pascal, SCCS, Modula-2, Ratfor…). Huge speedup and removes surprise rebuilds. Pair with `--no-builtin-variables` via `MAKEFLAGS += --no-builtin-variables` if you want to go further. |
| `.DEFAULT_GOAL := help` | Running bare `make` prints help instead of executing the first real target. Paired with the self-documenting `help` pattern below. |

### Optional but recommended

```make
.SUFFIXES:                              # clear legacy suffix rules entirely
.ONESHELL:                              # only if you want multi-line recipes in one shell (see caveats below)
MAKEFLAGS += --no-print-directory       # suppress "Entering/Leaving directory" noise for recursive make
```

Caveat on `.ONESHELL`: it changes semantics for every recipe in the file. Without it, each recipe **line** runs in a fresh shell (so `cd foo` in line 1 is gone by line 2). With it, the whole recipe is one shell invocation — `cd` persists, but a failure on line 2 only aborts if `-e` is set (which our `.SHELLFLAGS` does). If you enable `.ONESHELL`, test each recipe's failure behavior.

---

## SELF-DOCUMENTING HELP TARGET (CANONICAL PATTERN)

Every Makefile MUST include this `help` target and every user-facing target MUST carry a `## description` comment:

```make
.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "; printf "\nUsage: make \033[36m<target>\033[0m\n\nTargets:\n"} \
	     /^[a-zA-Z_0-9%\/-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
```

Usage convention in every target:

```make
.PHONY: build
build: ## Compile the binary into ./bin/app
	go build -o bin/app ./cmd/app
```

Running `make` (or `make help`) prints:

```
Usage: make <target>

Targets:
  help                 Show this help.
  build                Compile the binary into ./bin/app
  test                 Run unit tests
  ...
```

**Rule:** if a target has no `##` comment, it is internal-only. If it's user-facing, it MUST have one.

---

## TABS vs SPACES (NON-NEGOTIABLE)

- Recipe lines **MUST start with a literal TAB**. Spaces cause `*** missing separator` errors.
- Everything above the recipe (variable assignments, `.PHONY`, comments) uses whatever indentation you like — prefer none or 2 spaces.
- If you must use a different prefix, set `.RECIPEPREFIX := >` — but do NOT do this unless you have a specific reason. Tab is the universal convention; editors and diff tools expect it.
- Configure editors: `.editorconfig` should carry `[Makefile]\nindent_style = tab`.

---

## STANDARD TARGETS

Adopt the GNU conventions where they apply. Every Makefile should pick a coherent subset of:

| Target | Purpose | Phony? |
|--------|---------|--------|
| `help` | Print target list (see above) | Yes |
| `all` | Default build (typically depends on `build`) | Yes |
| `build` | Compile/assemble artifacts | Yes |
| `test` | Run unit tests | Yes |
| `test/integration` | Run integration tests | Yes |
| `lint` | Run linters (no fixes) | Yes |
| `fmt` | Apply formatters (writes files) | Yes |
| `check` | `fmt` + `lint` + `test` — single CI gate | Yes |
| `run` | Run the app locally | Yes |
| `clean` | Remove build artifacts | Yes |
| `install` | Install to `$(PREFIX)` (only for distributable tools) | Yes |
| `uninstall` | Reverse of `install` | Yes |
| `docker/build`, `docker/push` | Container workflow (use `/` to group) | Yes |
| `db/migrate`, `db/reset` | Database workflow | Yes |
| `tools` | Install dev tool binaries | Yes |

### Grouping convention

Use `/` (not `:` or `-`) to namespace related targets: `docker/build`, `docker/push`, `db/migrate`, `db/reset`, `ci/test`. Make treats `/` as an ordinary character in target names, and the convention keeps `make help` readable.

---

## PHONY TARGETS

Any target that does not produce a file by its own name MUST be declared phony. Without `.PHONY`, a stray file named `clean` in the working directory makes `make clean` silently do nothing.

Two styles — pick one and be consistent:

**Style A — declare once at the top (rare, fragile):**
```make
.PHONY: all build test lint fmt clean help
```

**Style B — declare immediately before each target (preferred):**
```make
.PHONY: build
build: ## Compile
	go build -o bin/app ./cmd/app

.PHONY: test
test: ## Run tests
	go test ./...
```

Style B localizes the declaration with the definition — when you delete the target, `.PHONY` disappears with it. Less rot.

---

## VARIABLES

### Flavor reference

| Operator | Flavor | When to use |
|----------|--------|-------------|
| `=` | Recursive — expanded on reference | Late binding; value depends on variables defined later |
| `:=` | Simple — expanded immediately | **Default choice.** Faster, predictable, no recursion surprises |
| `?=` | Conditional — only if unset | Defaults that users/env can override: `PREFIX ?= /usr/local` |
| `+=` | Append | Build up flag lists: `CFLAGS += -Wall` |
| `!=` | Shell assignment (GNU 4.0+) | Run a command at parse time: `GIT_SHA != git rev-parse HEAD` |
| `:::=` | Immediate-with-escape (GNU 4.4+) | Rare — use only if you know you need it and can require Make 4.4. macOS ships 3.81; CI still sees 4.1–4.3 commonly. |

**Default to `:=`.** Use `=` only when you deliberately want deferred expansion (e.g. `OBJS = $(SRCS:.c=.o)` where `SRCS` changes later in the file — but even here, `:=` is usually fine).

### Naming and override convention

```make
# User-overridable (lowercase-aware, convention is UPPER_SNAKE for Make variables)
PREFIX    ?= /usr/local
BINDIR    ?= $(PREFIX)/bin
BUILDDIR  ?= build
GO        ?= go
DOCKER    ?= docker
IMAGE     ?= myorg/myapp
TAG       ?= $(shell git rev-parse --short HEAD)

# Computed (simple expansion — evaluate once)
VERSION   := $(shell git describe --tags --always --dirty)
LDFLAGS   := -X main.version=$(VERSION)

# Internal (not intended for override)
_sources  := $(wildcard cmd/**/*.go internal/**/*.go)
```

- Use `?=` for anything a user, CI, or downstream Makefile might override.
- Use `:=` for anything you compute and want to freeze.
- Prefix genuinely internal variables with `_` to signal "don't override this."
- Prefer `$(GO)`, `$(DOCKER)`, `$(NPM)` indirection over hardcoded tool names — lets callers swap the implementation (`GO=go1.22 make build`).

### Automatic variables

Inside recipes only:

| Var | Meaning |
|-----|---------|
| `$@` | Target name |
| `$<` | First prerequisite |
| `$^` | All prerequisites (deduplicated) |
| `$+` | All prerequisites (with duplicates) |
| `$?` | Prerequisites newer than target |
| `$*` | Stem (the part that `%` matched in a pattern rule) |
| `$(@D)` / `$(@F)` | Directory / file portion of `$@` |
| `$(<D)` / `$(<F)` | Directory / file portion of `$<` |

In a shell-escape context (shell variables inside a recipe), double the dollar sign: `$$HOME`, `for f in $$(ls)`.

---

## PATTERN RULES

Prefer pattern rules over explicit per-file rules:

```make
$(BUILDDIR)/%.o: src/%.c | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILDDIR):
	mkdir -p $@
```

The `| $(BUILDDIR)` after `|` is an **order-only prerequisite** — `$(BUILDDIR)` must exist, but changes to its mtime (e.g. from dropping another file in) do NOT trigger a rebuild of `.o` files. Use this pattern for every output directory.

### Static pattern rules

When the pattern should only apply to a specific list:

```make
OBJS := $(patsubst src/%.c,$(BUILDDIR)/%.o,$(wildcard src/*.c))

$(OBJS): $(BUILDDIR)/%.o: src/%.c | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@
```

---

## FUNCTIONS (MOST-USED)

### Text / file manipulation
- `$(wildcard pattern)` — expand glob at parse time. `$(wildcard src/*.c)`.
- `$(patsubst from,to,text)` — pattern substitution. `$(patsubst %.c,%.o,$(SRCS))`.
- `$(subst from,to,text)` — literal substitution.
- `$(filter pat…,text)` / `$(filter-out pat…,text)` — keep/drop matching words.
- `$(sort list)` — sort + dedupe.
- `$(strip text)` — collapse whitespace.
- `$(notdir name)` / `$(dir name)` / `$(basename name)` / `$(suffix name)` — path parts.
- `$(addprefix p,names)` / `$(addsuffix s,names)` — glue prefix/suffix onto each word.
- `$(abspath name)` / `$(realpath name)` — canonical paths (realpath resolves symlinks).
- `$(word n,text)` / `$(words text)` / `$(wordlist s,e,text)` — word indexing.

### Shell / side-effects
- `$(shell cmd)` — run a shell command at parse time. Fires once per expansion — store the result in a `:=` variable.
- `$(info text)` / `$(warning text)` / `$(error text)` — print at parse time; `$(error)` aborts.

### Control flow
- `$(if cond,then[,else])` — cond is non-empty = true.
- `$(or a,b,c)` / `$(and a,b,c)` — short-circuit first non-empty / last if all non-empty.
- `$(foreach var,list,body)` — iterate. `$(foreach d,$(DIRS),$(d)/build)`.
- `$(call fn,args…)` — invoke a user-defined function (see below).
- `$(eval text)` — parse `text` as makefile syntax. Powerful and dangerous — use for dynamic rule generation, nothing else.

### User-defined functions

```make
define compile-lang
$(1)_OBJS := $$(patsubst %.$(1),%.o,$$(wildcard *.$(1)))
$$($(1)_OBJS): %.o: %.$(1)
	$(CC) -x $(1) -c $$< -o $$@
endef

$(eval $(call compile-lang,c))
$(eval $(call compile-lang,cpp))
```

Note the `$$` escaping — inside `define`, you want `$` to be literal in the generated text.

---

## CONDITIONAL SYNTAX

Conditionals run at **parse time**, so automatic variables (`$@`, `$<`) cannot appear in them — only plain variables.

```make
ifeq ($(GOOS),darwin)
  LDFLAGS += -Wl,-undefined,dynamic_lookup
else ifeq ($(GOOS),linux)
  LDFLAGS += -Wl,--as-needed
endif

ifdef DEBUG
  CFLAGS += -g -O0
else
  CFLAGS += -O2
endif

ifneq ($(shell which podman 2>/dev/null),)
  DOCKER := podman
else
  DOCKER := docker
endif
```

Prefer `ifeq` with explicit string compare over `ifdef` when the variable may be set-but-empty — `ifdef` treats empty strings as defined.

---

## INCLUDES AND MODULAR MAKEFILES

Split large Makefiles into topic files under `make/` or `mk/`:

```
Makefile
make/
├── go.mk
├── docker.mk
└── db.mk
```

```make
# Makefile
include make/go.mk
include make/docker.mk
-include make/local.mk       # optional, ignored if missing — per-developer overrides
```

- `include` — fatal if the file is missing.
- `-include` (or `sinclude`) — silent if missing. Use for optional local overrides.
- Paths are resolved relative to the current working directory, **not** the including makefile. If you use `-C` heavily, prefer absolute paths via `$(abspath …)`.

---

## RECURSIVE MAKE

When wrapping sub-projects:

```make
SUBDIRS := services/api services/worker

.PHONY: build
build: $(addsuffix /.build,$(SUBDIRS))

%/.build:
	$(MAKE) -C $* build
```

**Rules:**
- Always use `$(MAKE)`, never hardcoded `make` — respects `-n`, `-j`, and parent flags.
- `MAKEFLAGS` is auto-propagated.
- Set `MAKEFLAGS += --no-print-directory` at the top to suppress the "Entering/Leaving" noise unless you genuinely need it for debugging.
- **Recursive make is a smell** — per Peter Miller's "Recursive Make Considered Harmful." Prefer a single top-level Makefile with `include`s when dependency tracking across subprojects matters. Use recursion only when subprojects are genuinely independent (e.g. a monorepo of services with no shared build DAG).

---

## PARALLEL EXECUTION

- Run with `make -j` (unlimited) or `make -j$(nproc)` / `make -j8` (bounded).
- Parallel safety requires:
  - Every output directory declared as an **order-only** prerequisite (`| $(BUILDDIR)`), not a regular one.
  - No two targets write to the same file.
  - No target depends on side-effects of another that isn't in its prereq chain.
- Test parallelism with `make -j8 clean && make -j8 all` a few times — race conditions are timing-dependent.
- Use `.NOTPARALLEL:` sparingly to force serial execution of targets that truly can't parallelize (e.g. DB migrations).

---

## DEBUGGING MAKEFILES

| Command | Use |
|---------|-----|
| `make -n <target>` | Dry run — print recipes without executing |
| `make -p` | Print the internal database (all variables, rules, implicit rules) |
| `make --debug=v <target>` | Verbose reason-for-rebuild trace |
| `make --trace <target>` | GNU 4.0+ — show each rule as it fires, with line numbers |
| `$(info var=$(VAR))` | Parse-time print — drop in to inspect values |
| `$(warning VAR is empty)` | Parse-time warning |
| `$(error missing X)` | Parse-time abort with message |

Always test a new Makefile with `make -n` before letting it run destructive recipes.

---

## PORTABILITY GUIDELINES

- Assume GNU Make **4.0+** as a floor (covers all modern Linux, Homebrew macOS, current CI images). Note: default macOS `/usr/bin/make` is 3.81 (GPLv3 rejection). Document `brew install make` and suggest `gmake` in the README if you rely on 4.x features like `!=`, `--output-sync`, `$(file ...)`.
- For `:::=` and `$(let ...)` you need **4.4+** — only introduce these if you control the Make version.
- Do not rely on BSD Make or POSIX Make. This skill writes GNU Make.
- Inside recipes, use POSIX shell builtins and bash-only syntax (since we set `SHELL := bash`). Don't assume GNU coreutils on macOS — prefer `find . -name '*.x' -delete` over `find … -printf …`. Call out macOS/Linux `sed -i` differences with a portable pattern:
  ```make
  SED_INPLACE := sed -i$(if $(filter Darwin,$(shell uname)), '',)
  ```
- Quote shell expansions: `rm -rf "$(BUILDDIR)"`. Empty or whitespace-containing variables will tank you otherwise.

---

## LANGUAGE-SPECIFIC TEMPLATES

Pick the closest template and adapt. Each template assumes the prologue at the top of this skill.

### Go

```make
GO        ?= go
BIN       ?= bin
APP       ?= app
PKG       ?= ./...
LDFLAGS   := -s -w -X main.version=$(shell git describe --tags --always --dirty)

.PHONY: build
build: ## Compile the binary
	$(GO) build -trimpath -ldflags='$(LDFLAGS)' -o $(BIN)/$(APP) ./cmd/$(APP)

.PHONY: test
test: ## Run tests with race detector
	$(GO) test -race -count=1 $(PKG)

.PHONY: lint
lint: ## Run golangci-lint
	golangci-lint run $(PKG)

.PHONY: fmt
fmt: ## Format code
	gofmt -s -w .
	goimports -w .

.PHONY: tidy
tidy: ## Tidy modules
	$(GO) mod tidy

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(BIN)

.PHONY: check
check: fmt lint test ## Full local CI gate
```

### Node / TypeScript

```make
PNPM   ?= pnpm
NODE   ?= node

.PHONY: install
install: ## Install dependencies (frozen lockfile)
	$(PNPM) install --frozen-lockfile

.PHONY: build
build: ## Compile TypeScript
	$(PNPM) build

.PHONY: test
test: ## Run unit tests
	$(PNPM) test

.PHONY: lint
lint: ## Lint sources
	$(PNPM) lint

.PHONY: fmt
fmt: ## Format sources
	$(PNPM) format

.PHONY: dev
dev: ## Run dev server
	$(PNPM) dev

.PHONY: clean
clean: ## Remove build output
	rm -rf dist node_modules/.cache
```

### Python

```make
PY        ?= python3
UV        ?= uv
VENV      ?= .venv
PYTEST    := $(VENV)/bin/pytest
RUFF      := $(VENV)/bin/ruff

$(VENV)/bin/activate:
	$(UV) venv $(VENV)
	$(UV) pip install -e '.[dev]'

.PHONY: install
install: $(VENV)/bin/activate ## Create venv and install deps

.PHONY: test
test: install ## Run pytest
	$(PYTEST) -q

.PHONY: lint
lint: install ## Run ruff
	$(RUFF) check .

.PHONY: fmt
fmt: install ## Format with ruff
	$(RUFF) format .

.PHONY: clean
clean: ## Remove venv and caches
	rm -rf $(VENV) .pytest_cache .ruff_cache **/__pycache__
```

### .NET

```make
DOTNET    ?= dotnet
CONFIG    ?= Release
PROJECT   ?= src/App/App.csproj

.PHONY: restore
restore: ## Restore packages
	$(DOTNET) restore

.PHONY: build
build: restore ## Build solution
	$(DOTNET) build -c $(CONFIG) --no-restore

.PHONY: test
test: ## Run tests
	$(DOTNET) test -c $(CONFIG)

.PHONY: run
run: ## Run the app
	$(DOTNET) run --project $(PROJECT) -c $(CONFIG)

.PHONY: fmt
fmt: ## Format code
	$(DOTNET) format

.PHONY: clean
clean: ## Clean build output
	$(DOTNET) clean
	rm -rf **/bin **/obj
```

### C / C++

```make
CC        ?= cc
CFLAGS    ?= -Wall -Wextra -Werror -O2 -std=c17
LDFLAGS   ?=
SRC       := $(wildcard src/*.c)
OBJ       := $(patsubst src/%.c,build/%.o,$(SRC))
BIN       := build/app

.PHONY: all
all: $(BIN) ## Build everything

$(BIN): $(OBJ)
	$(CC) $(LDFLAGS) $^ -o $@

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

build:
	mkdir -p $@

-include $(OBJ:.o=.d)

.PHONY: clean
clean: ## Remove build/
	rm -rf build
```

Note the `-MMD -MP` flags generate `.d` files that the `-include` line pulls in — this gives automatic header dependency tracking. Standard idiom; worth internalizing.

### Docker

```make
IMAGE ?= myorg/myapp
TAG   ?= $(shell git rev-parse --short HEAD)

.PHONY: docker/build
docker/build: ## Build container image
	docker build -t $(IMAGE):$(TAG) -t $(IMAGE):latest .

.PHONY: docker/push
docker/push: docker/build ## Push image
	docker push $(IMAGE):$(TAG)
	docker push $(IMAGE):latest

.PHONY: docker/run
docker/run: ## Run image locally
	docker run --rm -it -p 8080:8080 $(IMAGE):$(TAG)
```

---

## GO MAKEFILE BEST PRACTICES

Adapted primarily from **Alex Edwards' "A Time-Saving Makefile for Your Go Projects"** (<https://www.alexedwards.net/blog/a-time-saving-makefile-for-your-go-projects>), with cross-compilation patterns from the **Earthly Golang Makefile guide** (<https://earthly.dev/blog/golang-makefile/>). Hardened for the strict prologue above.

### Why Make for Go

Edwards frames it: *"automate common admin tasks (like running tests, checking for vulnerabilities, pushing changes to a remote repository, and deploying to production)"* and *"provide short aliases for Go commands that are long or difficult to remember."* Go's native runner (`go`) is strong — the value of Make is gluing `go` together with `git`, `gofmt`, `staticcheck`, `govulncheck`, `upx`, SSH/rsync, and CI gates behind one stable set of target names.

### Section layout convention

For Go projects large enough to have more than ~10 targets, group them into labeled sections with banner comments — Edwards' four-section layout is a solid default:

```make
# ==================================================================================== #
# HELPERS
# ==================================================================================== #

# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

# ==================================================================================== #
# OPERATIONS
# ==================================================================================== #
```

`HELPERS` holds `help`, `confirm`, `no-dirty`. `QUALITY CONTROL` holds `audit`, `test`, `test/cover`, `upgradeable`. `DEVELOPMENT` holds `tidy`, `build`, `run`, `run/live`. `OPERATIONS` holds `push`, `production/deploy`.

### Alternative help pattern: sed + column

Edwards uses a help pattern that's shorter than the awk one at the top of this skill. It expects `## target: description` comments on the line **above** the rule:

```make
## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'

## build: build the application
.PHONY: build
build:
	go build -o /tmp/bin/$(BINARY_NAME) $(MAIN_PACKAGE_PATH)
```

| Pattern | Comment placement | Tooling needed |
|---------|-------------------|----------------|
| Awk (skill default) | `target: ## description` inline | `awk` (in every POSIX system) |
| Edwards (sed + column) | `## target: description` line above | `sed` + `column` (missing on Alpine without `util-linux`) |

Pick one per Makefile and be consistent. Edwards' form scans better in source; the awk form renders without `column`.

### Safety gates: `confirm` and `no-dirty`

Two tiny targets that pay for themselves the first time they save you from pushing half-finished work. Compose them as prerequisites on any destructive or remote-side-effect target.

```make
.PHONY: confirm
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

.PHONY: no-dirty
no-dirty:
	@test -z "$(shell git status --porcelain)"
```

Usage: `push: confirm audit no-dirty`. If the tree is dirty or the user types anything but `y`, Make aborts before the first real command runs.

### The `audit` target — CI in one call

Edwards' `audit` is the single most valuable target he proposes. It bundles the full quality gate:

```make
.PHONY: audit
audit: test ## Run all quality-control checks
	go mod tidy -diff
	go mod verify
	test -z "$(shell gofmt -l .)"
	go vet ./...
	go run honnef.co/go/tools/cmd/staticcheck@latest -checks=all,-ST1000,-U1000 ./...
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

- `go mod tidy -diff` — non-destructive; fails if `go.mod`/`go.sum` would change.
- `go mod verify` — checksums match the module cache.
- `test -z "$(shell gofmt -l .)"` — `gofmt -l` prints files needing formatting; `test -z` fails if the list is non-empty.
- `go vet ./...` — stdlib static analysis.
- `staticcheck` — third-party static analysis via `go run` (see below).
- `govulncheck` — Go's vulnerability scanner, via `go run`.

CI calls `make audit`. Developers call it before `push` (which has it as a prerequisite).

### `go run <tool>@version` — the tool-dependency pattern

Edwards' key insight: **don't install tools globally.** Use `go run` against a pinned or latest version instead:

```make
go run honnef.co/go/tools/cmd/staticcheck@latest ./...
go run golang.org/x/vuln/cmd/govulncheck@latest ./...
go run github.com/air-verse/air@latest
go run github.com/oligot/go-mod-upgrade@latest
```

Benefits:
- Zero setup — clone the repo, `make audit` works.
- Version recorded in the Makefile; bumping a tool is a diffable commit.
- No `brew install`, no GOPATH pollution, no "works on my machine."

Trade-off: `go run` compiles on a cold cache. In CI, cache `$GOPATH/pkg/mod` and `$GOCACHE` so the second run is instant.

For reproducibility, **pin versions** instead of using `@latest`:

```make
go run honnef.co/go/tools/cmd/staticcheck@2024.1.1 ./...
go run golang.org/x/vuln/cmd/govulncheck@v1.1.3 ./...
```

### Test flags: `-race -buildvcs`

```make
.PHONY: test
test: ## Run all tests
	go test -v -race -buildvcs ./...

.PHONY: test/cover
test/cover: ## Run tests and open HTML coverage report
	go test -v -race -buildvcs -coverprofile=/tmp/coverage.out ./...
	go tool cover -html=/tmp/coverage.out
```

- `-race` — race detector. Always on. The ~2x slowdown pays for itself the first race it catches.
- `-buildvcs` — embeds commit SHA + dirty flag in the test binary (accessible via `runtime/debug.BuildInfo`).
- Coverage profile goes to `/tmp/` — never in the repo, never in `.gitignore`.

### `tidy` bundles mod tidy + fix + fmt

```make
.PHONY: tidy
tidy: ## Tidy modfiles and format .go files
	go mod tidy -v
	go fix ./...
	go fmt ./...
```

`go fix` rewrites deprecated APIs to their current form — run it before `go fmt` so formatting lands on the rewritten AST.

### `build` output to /tmp/bin/

Edwards' ephemeral-output pattern: build artifacts land in `/tmp/bin/` instead of a project-relative `bin/`. No `.gitignore` entry needed, no accidental commits of binaries, no clutter in `ls`.

```make
MAIN_PACKAGE_PATH := ./cmd/api
BINARY_NAME       := api

.PHONY: build
build: ## Build the binary
	go build -o /tmp/bin/$(BINARY_NAME) $(MAIN_PACKAGE_PATH)

.PHONY: run
run: build ## Build and run
	/tmp/bin/$(BINARY_NAME)
```

Edwards deliberately avoids `go run` for `make run` because `go run` does not embed `-buildvcs` info — the binary from `make build` does.

Trade-off: on systems with a small `/tmp` or tmpfs, large Go binaries can fill it. If that matters, use a repo-local `$(BUILDDIR)` and `.gitignore` it.

### Hot reload with `air`

```make
.PHONY: run/live
run/live: ## Run with live reload
	go run github.com/air-verse/air@latest \
	  --build.cmd "make build" --build.bin "/tmp/bin/$(BINARY_NAME)" --build.delay "100" \
	  --build.include_ext "go,tpl,tmpl,html,css,scss,js,ts,sql" \
	  --misc.clean_on_exit "true"
```

`air` moved from `github.com/cosmtrek/air` to `github.com/air-verse/air` in 2024 — if you inherit an older Makefile, update the import path.

### Cross-compilation matrix

From the Earthly guide, extended with arm64. Useful for CLI tools and anything you ship to users:

```make
BUILD_DIR ?= /tmp/bin
PLATFORMS := darwin-amd64 darwin-arm64 linux-amd64 linux-arm64 windows-amd64

.PHONY: build/all
build/all: $(addprefix $(BUILD_DIR)/$(BINARY_NAME)-,$(PLATFORMS)) ## Build for all platforms

$(BUILD_DIR)/$(BINARY_NAME)-%: | $(BUILD_DIR)
	@os=$$(echo $* | cut -d- -f1); \
	 arch=$$(echo $* | cut -d- -f2); \
	 ext=""; [ "$$os" = "windows" ] && ext=".exe"; \
	 echo "Building $@$$ext"; \
	 GOOS=$$os GOARCH=$$arch CGO_ENABLED=0 go build \
	   -trimpath -ldflags='$(LDFLAGS)' \
	   -o $@$$ext $(MAIN_PACKAGE_PATH)

$(BUILD_DIR):
	mkdir -p $@
```

`CGO_ENABLED=0` produces a static binary — portable across glibc/musl, works in scratch containers. Drop it only if you genuinely link against C.

### Version injection via ldflags

Embed version, commit, and build time into the binary at link time:

```make
VERSION    := $(shell git describe --tags --always --dirty)
COMMIT     := $(shell git rev-parse --short HEAD)
BUILD_TIME := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS    := -s -w \
              -X 'main.version=$(VERSION)' \
              -X 'main.commit=$(COMMIT)' \
              -X 'main.buildTime=$(BUILD_TIME)'
```

- `-s -w` — strip symbol table and DWARF (smaller binary).
- `-trimpath` (on the `go build` command line, not in ldflags) — removes absolute file paths from the binary. Always use it.
- `-X 'pkg.variable=value'` — sets a package-level `var` at link time.

Exposed in Go:

```go
package main

var (
    version   = "dev"
    commit    = "unknown"
    buildTime = "unknown"
)
```

### Deploy target with safety preamble

Edwards' `push` and `production/deploy` both require `confirm audit no-dirty` as prerequisites — you cannot push or deploy past a failing gate:

```make
.PHONY: push
push: confirm audit no-dirty ## Audit, dirty-check, confirm, then git push
	git push

.PHONY: production/deploy
production/deploy: confirm audit no-dirty ## Build linux binary, compress, deploy
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build \
	  -trimpath -ldflags='$(LDFLAGS)' \
	  -o /tmp/bin/linux_amd64/$(BINARY_NAME) $(MAIN_PACKAGE_PATH)
	upx -5 /tmp/bin/linux_amd64/$(BINARY_NAME)
	rsync -avz /tmp/bin/linux_amd64/$(BINARY_NAME) deploy@prod:/opt/app/bin/
	ssh deploy@prod 'sudo systemctl restart app'
```

UPX `-5` typically halves binary size. Skip UPX if startup latency matters (decompression happens on every process start) or if your runtime environment blocks self-modifying executables (some container security policies).

### Upgradeable dependencies

```make
.PHONY: upgradeable
upgradeable: ## List direct deps with upgrades available
	go run github.com/oligot/go-mod-upgrade@latest
```

Interactive tool — prints a checklist of upgradeable direct dependencies and bumps the ones you select.

### Go-specific gotchas

| Gotcha | Fix |
|--------|-----|
| `go test` without `-race` in CI | Always `-race`. Catches data races before production. |
| `go build` without `-trimpath` | Binary contains local paths (`/Users/alex/project/...`). Use `-trimpath` for reproducible + leak-free builds. |
| Tools installed via `go install` drift across machines | Use `go run tool@version` so the version is pinned in the Makefile. |
| `go mod tidy` in CI modifies tracked files | Use `go mod tidy -diff` — fails on drift, does not modify. |
| `gofmt -l .` output ignored | Wrap in `test -z "$(shell gofmt -l .)"` so a non-empty output fails the recipe. |
| `go run tool@latest` downloads on every clean build | Cache `$GOPATH/pkg/mod` and `$GOCACHE` in CI. |
| Build artifact checked into git | Build to `/tmp/bin/` (Edwards) or add the dir to `.gitignore`. |
| `push` sends half-done work | `push: confirm audit no-dirty` — you cannot push past the gate. |
| Using `github.com/cosmtrek/air` | Moved to `github.com/air-verse/air` in 2024. |
| Cross-compiling with CGO | `CGO_ENABLED=0` unless you genuinely need C. Static binaries are portable across glibc/musl. |
| Embedding version via `$(shell git describe)` on every `$(VAR)` reference | Assign with `:=`, not `=` — compute once, use many. |
| `go run` a tool that reads `os.Args[0]` to self-identify | Some tools break under `go run`. Fall back to `go install` into `$GOBIN` for those specific tools. |

---

## .NET MAKEFILE BEST PRACTICES

Adapted from **"Using Makefile in .NET" by Egor Tarasov** (<https://astordev.github.io/articles/makefile/>), hardened for the strict prologue above and extended with EF Core, tool manifests, watch/hot-reload, coverage, and environment conventions.

### Why Make for .NET

`dotnet` is a capable native runner, so the question is not "replace dotnet" but "stabilize the interface developers and CI call." Tarasov puts it plainly: *"It all comes down to changes. Let's say folder structure changes, a command line argument is needed, or even the whole project is rewritten in another programming language."* A Makefile pins the contract — `make run`, `make test`, `make db/migrate` — so the commands survive SDK bumps, repo restructures, and even language rewrites.

### Solution vs project targeting

Pin the solution or entry project explicitly — don't rely on `dotnet`'s auto-discovery once the repo grows a second `.csproj`:

```make
DOTNET    ?= dotnet
SLN       ?= MyApp.sln
PROJECT   ?= src/App/App.csproj
TESTS     ?= tests
CONFIG    ?= Release
PORT      ?= 5154
```

Every recipe that can take a target should use `$(SLN)` or `$(PROJECT)`, not bare paths. This makes multi-project repos and solution-of-solutions layouts behave.

### Tool manifest (.config/dotnet-tools.json)

If the repo uses `dotnet ef`, `csharpier`, `reportgenerator`, or any other local tool, pin them in a manifest and expose a restore target:

```make
.PHONY: tools
tools: ## Restore local .NET tools from .config/dotnet-tools.json
	$(DOTNET) tool restore
```

Depend on `tools` from every recipe that consumes one (`fmt`, `db/migrate`, `test/coverage`).

### Watch / hot-reload

```make
.PHONY: watch
watch: ## Run with hot reload
	$(DOTNET) watch --project $(PROJECT) run
```

### Kill-by-port (hardened)

Tarasov's original is `kill \`lsof -t -i:5154\``. Under this skill's strict prologue (`.SHELLFLAGS := -eu -o pipefail -c`), that recipe fails when no process is listening — `lsof` returns empty, `kill` aborts with no args, `-e` kills the recipe. Guard it:

```make
.PHONY: kill
kill: ## Kill whatever is listening on $(PORT)
	@pids=$$(lsof -t -i:$(PORT) 2>/dev/null || true); \
	if [ -n "$$pids" ]; then kill $$pids && echo "killed $$pids"; else echo "nothing on :$(PORT)"; fi
```

Note the `|| true` on `lsof` and the `if [ -n … ]` guard — both required because of `-eu`.

### Dev-loop orchestration: run + probe + stay attached

This is Tarasov's central insight. To start the app in the background, hit an endpoint, then leave the app in the foreground, you need an **interactive** shell (for `fg` / job control), which Make's default non-interactive subshell lacks:

```make
YAC       ?= httpyac

.PHONY: probe
probe: ## Hit .http endpoints against the running app
	$(YAC) send .http --all

.PHONY: play
play: ## Run app, probe once, keep running in the foreground
	bash -c -i '$(MAKE) run & \
	  until curl -sf http://localhost:$(PORT)/health >/dev/null 2>&1; do sleep 0.2; done; \
	  $(MAKE) probe && fg'
```

**Gotchas:**
- `bash -c -i` is mandatory — without `-i`, `fg` fails with `no job control`.
- The article uses `sleep 2` as a wait. That's fragile — replace with a poll (`until curl -sf … ; do sleep 0.2; done`) against a health endpoint. Two seconds is "works on my machine" territory.
- `$(MAKE)` (not `make`) inside the wrapped command — respects `-n`, `-j`, and `MAKEFLAGS` from the parent invocation.
- Prefer `httpyac` or `.http` files over inline `curl` for requests you want to commit; they render in VS Code, Rider, and Visual Studio.

Example `.http` file (committed alongside the Makefile):

```http
GET http://localhost:5154/
```

### EF Core migrations

Require `tools` so `dotnet ef` is available, and gate destructive targets on a `NAME` variable:

```make
MIGRATIONS_PROJECT ?= src/Infrastructure/Infrastructure.csproj
STARTUP_PROJECT    ?= src/App/App.csproj

.PHONY: db/migrate
db/migrate: tools ## Apply migrations to the current database
	$(DOTNET) ef database update \
	  --project $(MIGRATIONS_PROJECT) \
	  --startup-project $(STARTUP_PROJECT)

.PHONY: db/add
db/add: tools ## Add migration NAME=<name>
	@test -n "$(NAME)" || { echo "NAME=<migration-name> required"; exit 1; }
	$(DOTNET) ef migrations add $(NAME) \
	  --project $(MIGRATIONS_PROJECT) \
	  --startup-project $(STARTUP_PROJECT)

.PHONY: db/remove
db/remove: tools ## Remove the most recent migration
	$(DOTNET) ef migrations remove \
	  --project $(MIGRATIONS_PROJECT) \
	  --startup-project $(STARTUP_PROJECT)

.PHONY: db/reset
db/reset: tools ## Drop and re-apply all migrations (DEV ONLY)
	$(DOTNET) ef database drop --force \
	  --project $(MIGRATIONS_PROJECT) \
	  --startup-project $(STARTUP_PROJECT)
	$(MAKE) db/migrate
```

The `NAME` guard turns a silent misuse (`make db/add` creating an empty-named migration) into a clear error.

### Environment-scoped run targets

ASP.NET Core reads `ASPNETCORE_ENVIRONMENT`. Use **target-scoped** `export` so the variable only leaks into the recipe that needs it:

```make
.PHONY: run
run: export ASPNETCORE_ENVIRONMENT := Development
run: ## Run with Development config
	$(DOTNET) run --project $(PROJECT) -c $(CONFIG)

.PHONY: run/prod-local
run/prod-local: export ASPNETCORE_ENVIRONMENT := Production
run/prod-local: ## Run with Production config locally (requires secrets)
	$(DOTNET) run --project $(PROJECT) -c $(CONFIG)
```

Target-scoped variables are cleaner than a global `export` — no action at a distance.

### Coverage

```make
COVERAGE_DIR ?= coverage

.PHONY: test/coverage
test/coverage: tools ## Run tests with coverage HTML report
	rm -rf $(COVERAGE_DIR)
	$(DOTNET) test $(TESTS) \
	  --collect:"XPlat Code Coverage" \
	  --results-directory $(COVERAGE_DIR)
	$(DOTNET) reportgenerator \
	  -reports:"$(COVERAGE_DIR)/**/coverage.cobertura.xml" \
	  -targetdir:"$(COVERAGE_DIR)/report" \
	  -reporttypes:Html
	@echo "Open $(COVERAGE_DIR)/report/index.html"
```

### Format and lint gates

`dotnet format` is built in; pair with `csharpier` for opinionated formatting and provide both a writer and a CI-check variant:

```make
.PHONY: fmt
fmt: tools ## Format code (writes files)
	$(DOTNET) format $(SLN)
	$(DOTNET) csharpier format .

.PHONY: fmt/check
fmt/check: tools ## Verify formatting without writing (for CI)
	$(DOTNET) format $(SLN) --verify-no-changes
	$(DOTNET) csharpier check .
```

### Publish

Self-contained publish for container images or releases:

```make
RID         ?= linux-x64
PUBLISH_DIR ?= publish

.PHONY: publish
publish: ## Publish self-contained to $(PUBLISH_DIR)
	$(DOTNET) publish $(PROJECT) \
	  -c $(CONFIG) \
	  -r $(RID) \
	  --self-contained true \
	  -p:PublishSingleFile=true \
	  -o $(PUBLISH_DIR)
```

### .NET-specific gotchas

| Gotcha | Fix |
|--------|-----|
| Bare `kill \`lsof …\`` under strict shell flags | Guard with `pids=$$(lsof -t -i:$(PORT) 2>/dev/null || true)` + `if [ -n "$$pids" ]` |
| `dotnet ef` "command not found" in CI | `tools` must run first — `dotnet tool restore` |
| `make run & fg` fails with "no job control" | Wrap in `bash -c -i '…'` |
| `sleep N` before probing an endpoint | Poll with `until curl -sf $(URL) >/dev/null; do sleep 0.2; done` |
| `dotnet run` without `--project` in multi-project repo | Always pass `--project $(PROJECT)` |
| Coverage reports landing in git-tracked folders | Add `$(COVERAGE_DIR)/` to `.gitignore` and `rm -rf` at the start of the target |
| `ASPNETCORE_ENVIRONMENT` leaking from one target to another | Use **target-scoped** `export`, not global `export` |
| `dotnet watch` hanging on file-save in Docker volumes | Set `DOTNET_USE_POLLING_FILE_WATCHER=1` in the recipe |

---

## PYTHON MAKEFILE BEST PRACTICES

Synthesized from three sources: **"The Case for Makefiles in Python Projects" (KDnuggets)** (<https://www.kdnuggets.com/the-case-for-makefiles-in-python-projects-and-how-to-get-started>), **"Python Makefile" (Earthly)** (<https://earthly.dev/blog/python-makefile/>), and **"Advanced Makefile Tips for Python Projects" (Glinteco)** (<https://glinteco.com/en/post/advanced-makefile-tips-tricks-and-best-practices-for-python-projects/>). Extended with modern tooling (`uv`, `ruff`, `mypy`, `pre-commit`) and hardened for the strict prologue above.

### Why Make for Python

The KDnuggets article frames it in three points:

1. **Consistency** — *"When everyone on your team runs `make test` instead of remembering the exact pytest command with all its flags, you eliminate the 'works on my machine' problem."*
2. **Documentation** — `make help` becomes the canonical list of tasks for newcomers.
3. **Workflow compression** — multi-step operations (create venv → install deps → run migrations → start server) collapse to `make dev`.

Python specifically benefits because the tool landscape is fragmented (pip vs poetry vs uv, pytest vs unittest, black vs ruff, flake8 vs pylint vs ruff, mypy vs pyright). A Makefile pins your team's choices behind stable target names.

### THE activation problem (read this first)

Make runs each recipe line in a **fresh shell**. That means:

```make
# BROKEN — does not work
run:
	source venv/bin/activate   # activates in shell A
	python app.py              # shell B — venv is gone
```

Three correct patterns — pick one:

**Pattern A (preferred): call the venv python directly.**
```make
VENV   ?= .venv
PYTHON := $(VENV)/bin/python

run:
	$(PYTHON) app.py
```
No activation needed. `$(VENV)/bin/python` finds `$(VENV)/bin/pytest`, `$(VENV)/bin/ruff`, etc. via `sys.path` automatically.

**Pattern B: chain with `&&` on one logical line.**
```make
run:
	. $(VENV)/bin/activate && python app.py
```
Works but adds a subshell layer that clutters tracebacks.

**Pattern C: `.ONESHELL:` at the top of the file.**
```make
.ONESHELL:
run:
	source $(VENV)/bin/activate
	python app.py
```
Changes semantics for every recipe in the file — see the `.ONESHELL` caveat in the prologue section.

**Use Pattern A by default.** It's the cleanest and plays nicely with `-eu -o pipefail`.

### The venv-as-file-target pattern (Earthly's insight)

Earthly's best idea: treat `$(VENV)/bin/activate` as a **file target** that depends on `requirements.txt` or `pyproject.toml`. Make rebuilds the venv automatically when dependencies drift.

```make
VENV    ?= .venv
PYTHON  := $(VENV)/bin/python
PIP     := $(VENV)/bin/pip

$(VENV)/bin/activate: requirements.txt
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	@touch $@

.PHONY: install
install: $(VENV)/bin/activate ## Install/update deps if requirements.txt changed

.PHONY: run
run: install ## Run the app
	$(PYTHON) app.py
```

- First `make run` creates the venv and installs deps.
- Second `make run` skips reinstall (activate is newer than requirements.txt).
- Edit `requirements.txt` → next `make run` reinstalls automatically.
- The `@touch $@` handles the case where pip runs but `activate`'s mtime doesn't change.

Substitute `requirements.txt` with `pyproject.toml` and/or `uv.lock` for modern projects.

### Package manager paths

Modern Python has three viable paths. Pick ONE per project; don't mix.

**Path 1: uv (recommended for new projects).** Fastest, built in Rust, handles venv + lockfile + install in one tool. Replaces pip + pip-tools + virtualenv.

```make
UV     ?= uv
VENV   ?= .venv
PYTHON := $(VENV)/bin/python

$(VENV)/bin/activate: pyproject.toml uv.lock
	$(UV) sync
	@touch $@

.PHONY: lock
lock: ## Re-resolve dependencies and update uv.lock
	$(UV) lock

.PHONY: add
add: ## Add a dependency: make add PKG=requests
	@test -n "$(PKG)" || { echo "PKG=<package> required"; exit 1; }
	$(UV) add $(PKG)
```

**Path 2: poetry.** Mature, lockfile-based, opinionated. Slower than uv but widely adopted.

```make
POETRY ?= poetry

.PHONY: install
install: ## Install deps from poetry.lock
	$(POETRY) install

.PHONY: lock
lock: ## Re-resolve dependencies
	$(POETRY) lock --no-update
```

Run project commands through `$(POETRY) run pytest`, or resolve the venv path once (`VENV := $(shell $(POETRY) env info --path)`) and use Pattern A.

**Path 3: pip + pip-tools (traditional).** Split `requirements.in` (human-edited) and `requirements.txt` (pinned, generated).

```make
requirements.txt: requirements.in
	$(PYTHON) -m piptools compile $<

.PHONY: lock
lock: requirements.txt ## Regenerate requirements.txt from requirements.in

$(VENV)/bin/activate: requirements.txt
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip pip-tools
	$(PYTHON) -m piptools sync requirements.txt
	@touch $@
```

`pip-tools sync` is destructive — it removes packages not in the lockfile. That's the feature; it prevents environment drift.

### Quality gates: format, lint, typecheck, test

Modern consensus: use `ruff` for both formatting AND linting (replaces black + isort + flake8 + pyupgrade, roughly 100× faster). Pair with `mypy` for type checking.

```make
RUFF   := $(VENV)/bin/ruff
MYPY   := $(VENV)/bin/mypy
PYTEST := $(VENV)/bin/pytest

.PHONY: fmt
fmt: install ## Format code (writes files)
	$(RUFF) format .
	$(RUFF) check --fix .

.PHONY: lint
lint: install ## Lint + format check (CI-safe, no writes)
	$(RUFF) check .
	$(RUFF) format --check .

.PHONY: typecheck
typecheck: install ## Static type check
	$(MYPY) src tests

.PHONY: test
test: install ## Run tests
	$(PYTEST) -v

.PHONY: test/cover
test/cover: install ## Run tests with HTML coverage report
	$(PYTEST) -v --cov=src --cov-report=html --cov-report=term
	@echo "Open htmlcov/index.html"

.PHONY: check
check: lint typecheck test ## Full local CI gate
```

If the project still uses black / isort / flake8 (KDnuggets' stack):

```make
.PHONY: fmt
fmt: install
	$(PYTHON) -m black .
	$(PYTHON) -m isort .

.PHONY: lint
lint: install
	$(PYTHON) -m flake8 src tests
	$(PYTHON) -m black --check .
	$(PYTHON) -m isort --check-only .
```

### Pre-commit integration

```make
PRE_COMMIT := $(VENV)/bin/pre-commit

.PHONY: hooks
hooks: install ## Install git pre-commit hooks
	$(PRE_COMMIT) install

.PHONY: hooks/run
hooks/run: install ## Run pre-commit on every file
	$(PRE_COMMIT) run --all-files
```

Add `hooks` to your `dev` target so new contributors get hooks wired up automatically.

### Environment-conditional deployment (KDnuggets)

```make
ENV ?= staging

.PHONY: deploy
deploy: ## Deploy to $(ENV)
ifeq ($(ENV),production)
	@echo "Deploying to production"
	./scripts/deploy_prod.sh
else ifeq ($(ENV),staging)
	@echo "Deploying to staging"
	./scripts/deploy_staging.sh
else
	@echo "Unknown ENV=$(ENV)"; exit 1
endif
```

Invoke with `make deploy ENV=production`.

### dev / serve / shell — ergonomic entry points

```make
.PHONY: dev
dev: install hooks ## Bootstrap the dev environment
	@echo "Ready. Try: make serve"

.PHONY: serve
serve: install ## Run the dev server
	$(PYTHON) -m flask run --debug

.PHONY: shell
shell: install ## IPython REPL with app context
	$(PYTHON) -c "from src.app import create_app; \
	  app = create_app(); app.app_context().push(); \
	  import IPython; IPython.start_ipython()"
```

### Database migrations (Alembic / Django)

```make
# Alembic
.PHONY: db/migrate
db/migrate: install ## Apply alembic migrations
	$(VENV)/bin/alembic upgrade head

.PHONY: db/revision
db/revision: install ## Autogenerate migration: make db/revision MSG="add users"
	@test -n "$(MSG)" || { echo "MSG=<message> required"; exit 1; }
	$(VENV)/bin/alembic revision --autogenerate -m "$(MSG)"

# Django
.PHONY: django/migrate
django/migrate: install
	$(PYTHON) manage.py migrate

.PHONY: django/makemigrations
django/makemigrations: install
	$(PYTHON) manage.py makemigrations
```

### Clean: caches, build output, venv

Python scatters cache directories everywhere. Purge them all — but keep the venv-removal behind a separate target so `clean` stays fast.

```make
.PHONY: clean
clean: ## Remove caches and build output (keeps venv)
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name '*.pyc' -delete
	find . -type d -name '*.egg-info' -exec rm -rf {} +
	rm -rf build/ dist/ .pytest_cache/ .ruff_cache/ .mypy_cache/ htmlcov/ .coverage coverage.xml

.PHONY: clean/all
clean/all: clean ## Also remove the venv (forces full rebuild)
	rm -rf $(VENV)
```

Users want a fast `make clean && make test` cycle without paying for venv recreation. `clean/all` is the nuclear option.

### Python-specific gotchas

| Gotcha | Fix |
|--------|-----|
| `source venv/bin/activate` doesn't persist between recipe lines | Call `$(VENV)/bin/python` directly (Pattern A), or chain with `&&`, or enable `.ONESHELL:` |
| Multiple package managers in one project (pip + poetry + uv) | Pick one. Delete the others' lockfiles (`requirements.txt` vs `poetry.lock` vs `uv.lock`) |
| `make install` reinstalls every time | Use venv-as-file-target: `$(VENV)/bin/activate: requirements.txt` |
| `pyproject.toml` changed but pip didn't pick it up | Use a lockfile (`uv.lock`, `poetry.lock`, or pip-tools–generated `requirements.txt`) |
| `pip install -r requirements.txt` leaves stale deps behind | `pip install` is additive; `pip-sync` (or `uv sync`) is destructive and matches the lockfile exactly — prefer the destructive form in CI |
| `make clean` removes the venv and the next test takes 30s | Keep venv out of `clean`; put it in `clean/all` |
| `.pyc` / `__pycache__` scattered in commits | `.gitignore` them; `make clean` purges them |
| Manipulating `PYTHONPATH` inside recipes | Don't — use `pip install -e .` (editable install) via `pyproject.toml` instead |
| `python` vs `python3` on different OSes | Bootstrap with `python3 -m venv`; after that, use `$(VENV)/bin/python` which is unambiguous |
| Ruff and Black both configured with conflicting rules | Pick one formatter. `ruff format` ≈ `black` semantically; remove black from `pyproject.toml` |
| `mypy` complaining about third-party packages without stubs | Add `[[tool.mypy.overrides]]` in `pyproject.toml` or install `types-<package>` stubs |
| `pytest` can't find tests | Configure `[tool.pytest.ini_options] testpaths = ["tests"]` in `pyproject.toml` |
| `pre-commit` runs ruff via its own pin, Make uses `$(RUFF)` — versions drift | Pin ruff version in both `pyproject.toml` and `.pre-commit-config.yaml`; `pre-commit autoupdate` regularly |
| `$(shell python3 --version)` at parse time but venv not built yet | Parse-time `$(shell …)` runs before recipes. Don't depend on venv python at parse time — only inside recipes |
| Building wheels inside `clean/all` target runs | Always run `make install` first; don't assume tools exist after `clean/all` |

---

## ANTI-PATTERNS

| Anti-pattern | Why it's bad |
|--------------|--------------|
| Missing `.PHONY` on action targets | Stray file named `clean` makes `make clean` a no-op |
| Hardcoded `bin/sh` or default `SHELL` | Recipes behave differently on Debian (dash) vs macOS (bash-as-sh) |
| No `.DELETE_ON_ERROR` | Partial outputs survive recipe failures and look "up to date" |
| Recipes swallow errors in pipes without `pipefail` | `do_thing \| tee log` succeeds even if `do_thing` crashed |
| Spaces instead of tabs for recipe indentation | `*** missing separator` — the classic |
| Generating files outside their declared target name | Parallel make races; `make clean` doesn't remove them |
| Long inline shell one-liners chaining `&&` across 5 lines | Use `.ONESHELL:` on the file (with `-eu -o pipefail`) or extract to a `scripts/` file |
| `rm -rf $(VAR)` without quoting or without default | Empty `VAR` → `rm -rf` at repo root |
| Recursive make with shared state across subdirs | Breaks dependency DAG; prefer include-based flat Makefile |
| Using `=` everywhere | Re-expands on every reference; slow and full of late-binding surprises |
| No `help` target | Users `cat` the Makefile to find targets |
| Copying `node_modules`/`vendor`/`venv` into `clean` without care | Bricks the workspace; prefer language-native clean commands |
| Using `$(shell git …)` in every recipe instead of caching | Git invocation on every expansion — slow |
| Wrapping a single-line `npm test` behind `make test` | Just use `npm test`. Don't add Make for the sake of Make. |

---

## QUICK REFERENCE: AUTHORING A NEW MAKEFILE

1. **Decide if Make is even right** — single tool, single command? Stop. Multiple tools stitched together? Continue.
2. **Drop in the prologue:** `SHELL`, `.SHELLFLAGS`, `.DELETE_ON_ERROR`, `MAKEFLAGS`, `.DEFAULT_GOAL := help`.
3. **Add the `help` target** with the awk pattern.
4. **Pick the language template** and adapt variable defaults (`?=`) to the project.
5. **Add `## help text`** to every user-facing target.
6. **Declare `.PHONY`** immediately above every non-file target.
7. **Namespace grouped targets** with `/`: `docker/build`, `db/migrate`.
8. **Add a `check` target** that combines `fmt` + `lint` + `test` — CI calls this one target.
9. **Test:**
   - `make` (should print help).
   - `make -n build` (dry run — recipes look right).
   - `make check` (real run).
   - `make -j8 clean && make -j8 all` (parallel-safe).
10. **Document in README:** minimum GNU Make version (typically 4.0+), any tool prerequisites (`brew install make` on macOS if you use 4.x features).

---

## VERIFICATION BEFORE DECLARING DONE

- [ ] Prologue present and unmodified (SHELL, SHELLFLAGS, DELETE_ON_ERROR, MAKEFLAGS, DEFAULT_GOAL).
- [ ] `help` target present and prints all `##`-documented targets.
- [ ] Every user-facing target has `##` documentation.
- [ ] Every non-file target has `.PHONY`.
- [ ] No spaces-for-tabs (`cat -A Makefile \| grep -E "^ +[^ ]"` returns nothing).
- [ ] Recipes use `$(MAKE)` not `make`, `$(GO)` not `go`, etc. — tool indirection.
- [ ] Output directories are order-only prerequisites (`| $(BUILDDIR)`).
- [ ] `make -n all` prints recipes without errors.
- [ ] `make -j8 clean && make -j8 all` succeeds twice in a row (idempotent + parallel-safe).
- [ ] Every `$(shell ...)` result is captured with `:=`, not re-run on every reference.
- [ ] No recipes assume `pwd` persists between lines unless `.ONESHELL:` is set.
