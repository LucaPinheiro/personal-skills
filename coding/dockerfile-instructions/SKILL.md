---
name: dockerfile-instructions
description: MUST USE when creating, reviewing, or modifying a Dockerfile, Containerfile, or *.Dockerfile. Use when the user asks to "write a Dockerfile", "containerize an app", "shrink an image", "speed up docker build", "multi-stage build", "multi-arch build", "buildx", "cross-compile for arm64", "distroless", or wires up a container build in CI. Covers BuildKit prerequisites, multi-stage builds, size + build-time optimization (layer order, cache mounts, bind mounts, secret mounts, cache backends), multi-architecture builds (buildx, QEMU, TARGETPLATFORM, manifest lists), per-language templates (Go, Node/TS, Python, .NET, Rust, Java), .dockerignore, non-root USER, HEALTHCHECK, pinned base images, and CI patterns. Does NOT replace language build tools — wraps them inside reproducible, minimal container images.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: build-tooling
  pattern: container-image-build
---

# Dockerfile Authoring Skill — Multi-Stage, Optimized, Multi-Arch

You are a container-build expert authoring Dockerfiles that are **minimal, reproducible, fast to build, and portable across CPU architectures**. This skill synthesizes the official Docker documentation (multi-stage builds, BuildKit, buildx) with deep-dive material from iximiuz Labs, Blacksmith, and OneUptime into opinionated rules you apply every time a Dockerfile is created or edited. Dockerfiles authored by this skill **always** use multi-stage builds, **always** ship with a `.dockerignore`, and **always** target BuildKit — never the legacy builder.

---

## WHEN TO USE THIS SKILL

| Scenario | Use this skill? |
|----------|-----------------|
| User asks to "write/add/scaffold a Dockerfile" | **Yes** |
| User asks to "containerize" an application | **Yes** |
| User asks to "shrink", "slim", "optimize" an image | **Yes** |
| User asks about multi-stage builds, BuildKit, `COPY --from`, or stage targeting | **Yes** |
| User asks about multi-arch / cross-platform / `buildx` / Apple Silicon / Graviton / Raspberry Pi | **Yes** |
| Modifying an existing `Dockerfile`, `Containerfile`, or `*.Dockerfile` | **Yes** |
| CI job invokes `docker build` / `docker buildx build` | **Yes** — also configure the cache backend |
| User wants a one-off ad-hoc container for local scripting with no distribution need | **No** — a devcontainer, `docker run` with a volume, or `nix` may fit better |
| User is targeting Podman/Buildah exclusively and needs Podman-specific Containerfile quirks | **Caution** — most rules apply, but call out Podman-specific differences |

### When NOT to use a custom Dockerfile

- **Language has a first-party reproducible image tool** and you have no customization needs: prefer `ko` (Go), `jib` (Java/Maven/Gradle), `pack` (Cloud Native Buildpacks), `nixpacks`, or `.NET` SDK's `dotnet publish /t:PublishContainer`. They produce better images than most hand-written Dockerfiles. Only reach for a Dockerfile when you need control those tools don't give you.
- **Your platform already gives you a container image** (e.g. Google Cloud Run source deploys, Fly.io auto-Dockerfile, Railway buildpacks) and you're not fighting it.
- **You're trying to package a GUI desktop app** — containers are the wrong abstraction; use platform-native packaging.

---

## NON-NEGOTIABLE PROLOGUE

Every Dockerfile this skill authors MUST satisfy these preconditions and directives. They are the Dockerfile equivalent of the Makefile `SHELL`/`.SHELLFLAGS`/`.DELETE_ON_ERROR` prologue — not optional.

### 1. BuildKit is assumed — always

Every technique in this skill (`--mount=type=cache|bind|secret`, `--cache-from`/`--cache-to`, multi-stage parallelism, `buildx`, multi-arch) **requires BuildKit**. Legacy builder output is not supported.

- Docker 23.0+ uses BuildKit by default.
- On older Docker, export `DOCKER_BUILDKIT=1` or install `docker-buildx-plugin`.
- The `# syntax=` directive at the **very first line** pins the Dockerfile frontend version and unlocks the newest syntax:

```dockerfile
# syntax=docker/dockerfile:1.9
```

Put this on line 1. Without it, `--mount=type=cache` and newer features silently parse as comments.

### 2. Pin base images by digest in production Dockerfiles

Tags are mutable. `FROM node:22-slim` today is not the same bytes as `FROM node:22-slim` in three months. For reproducibility and supply-chain safety:

```dockerfile
# Development / early-stage: tag is acceptable
FROM node:22-slim AS base

# Production: pin the digest
FROM node:22-slim@sha256:abc123...deadbeef AS base
```

Obtain the digest with `docker buildx imagetools inspect node:22-slim`. Automate refresh with Renovate/Dependabot — they understand digest pinning.

### 3. Always ship a `.dockerignore`

Without `.dockerignore`, every `docker build` sends your entire working tree to the daemon (including `.git`, `node_modules`, `target/`, secrets). This is slow, leaks data into layers, and breaks cache. Treat `.dockerignore` as part of the Dockerfile — if one exists, the other must too. See [the dedicated section](#dockerignore) below.

### 4. Use multi-stage — single-stage is an anti-pattern for production

If the application has a build step (compile, bundle, transpile, install dev dependencies), the Dockerfile MUST be multi-stage. Single-stage Dockerfiles for compiled languages ship the entire toolchain to production — an 800 MB image where a 20 MB one would do. Details in [Multi-Stage Builds](#multi-stage-builds).

### 5. Drop root before `CMD`/`ENTRYPOINT`

The final stage MUST declare a non-root `USER` (and, where possible, a read-only root filesystem at runtime). Containers running as UID 0 are one container-escape away from host root. Details in [Security Hardening](#security-hardening).

### 6. Add a `HEALTHCHECK` for long-running services

Orchestrators (Kubernetes, ECS, Docker Swarm, Nomad) and local `docker compose` all honor `HEALTHCHECK`. Omitting it means the runtime cannot tell a crashed process from a wedged one. Details in [Runtime Hygiene](#runtime-hygiene).

---

## MULTI-STAGE BUILDS

### The problem multi-stage solves

A single-stage Dockerfile for a compiled language bundles the **build environment** (compiler, package manager caches, source, test fixtures, dev dependencies, secrets) into the **runtime image**. The runtime only needs the compiled artifact plus the minimal runtime libraries.

Numbers from the official Docker docs for a Spring Boot app: **880 MB single-stage → 428 MB multi-stage (51 % reduction)**, achieved simply by copying the built JAR from a `JDK` stage into a `JRE` final stage. Real-world Go binaries typically go from 800 MB+ (full `golang:` image) to **5–20 MB** (distroless or `scratch` final stage) — two orders of magnitude.

### Core syntax

```dockerfile
# syntax=docker/dockerfile:1.9

# --- Build stage ---
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app ./cmd/app

# --- Runtime stage ---
FROM gcr.io/distroless/static-debian12:nonroot AS runtime
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

The rules:

| Rule | Why |
|------|-----|
| **Name every stage** with `AS <name>` | Integer references (`COPY --from=0`) break silently when stages are reordered. |
| **Stage order matters** — a stage can only `COPY --from=` a **previously defined** stage | The BuildKit DAG is built top-down. Forward references are a parse error. |
| **Default build target is the last stage**; all stages it transitively copies from are executed, independent stages are skipped | Use this to hide helper stages. `FROM golangci/golangci-lint AS lint` won't run unless something depends on it or you pass `--target lint`. |
| Use `--target <stage>` to build a specific stage | Enables `make lint` / `make test` / `make debug-image` from the same Dockerfile. |
| Use `COPY --from=<image>:<tag>` to copy from an **external** image | No need for a `FROM` for utility images: `COPY --from=nginx:alpine /etc/nginx/nginx.conf /nginx.conf`. |
| **Parallel execution is automatic** — independent stages run concurrently under BuildKit | No orchestration needed; just keep stages independent. |

### `--target` for debugging, testing, and multi-output Dockerfiles

```dockerfile
FROM node:22-slim AS base
WORKDIR /app
COPY package*.json ./

FROM base AS deps
RUN npm ci

FROM deps AS test
COPY . .
RUN npm test                        # run only with: docker buildx build --target test .

FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM nginx:alpine AS runtime
COPY --from=build /app/dist /usr/share/nginx/html
```

Commands:

```bash
docker buildx build --target test -t myapp:test .      # run tests, don't build runtime
docker buildx build --target build -t myapp:build .    # stop at built artifacts
docker buildx build -t myapp:latest .                  # default: build runtime
```

### Legacy builder vs BuildKit

The legacy builder (pre-BuildKit) walked every stage up to the target, even unused ones. **BuildKit only executes stages the target transitively depends on.** This alone makes multi-purpose Dockerfiles (with optional `test`, `lint`, `debug` stages) practical — unused stages are free.

### Stage reuse — inherit from an earlier stage

```dockerfile
FROM debian:bookworm-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl && rm -rf /var/lib/apt/lists/*

FROM base AS build1
RUN curl -fsSL https://example.com/a | sh

FROM base AS build2
RUN curl -fsSL https://example.com/b | sh

FROM base AS runtime
COPY --from=build1 /opt/a /opt/a
COPY --from=build2 /opt/b /opt/b
```

`base` is built once. `build1` and `build2` run in parallel. `runtime` waits on both.

---

## OPTIMIZATION FOR IMAGE SIZE

Size matters because it drives:
- **Registry storage + bandwidth** (pulls cost real money at scale).
- **Cold-start latency** on Kubernetes/Lambda/Cloud Run — image pull dominates boot time.
- **Attack surface** — every package in the image is a CVE candidate. `golang:1.23` ships **799+ known vulnerabilities** (2 CRITICAL) per scanners; `gcr.io/distroless/static` ships **zero**.

### Runtime base-image decision tree

Pick the smallest final-stage base your binary tolerates. In order of decreasing size:

| Final base | Size | Use when |
|------------|------|----------|
| `ubuntu:24.04` / `debian:bookworm` | ~80 MB | You need `apt` at runtime (rare). |
| `debian:bookworm-slim` | ~30 MB | You need a shell + basic libc + package manager you won't use. |
| `alpine:3.20` | ~5 MB | You accept musl libc + apk. Watch for glibc-only Go binaries, Node native modules, Python wheels. |
| `gcr.io/distroless/cc-debian12` | ~20 MB | Dynamically linked glibc binaries. No shell — no `docker exec sh`. |
| `gcr.io/distroless/static-debian12:nonroot` | ~2 MB | **Default for Go**, Rust `musl`, any fully static binary. Ships CA certs + `/etc/passwd`. |
| `scratch` | 0 MB | Absolutely static binary, no CA certs, no `/etc/passwd`. Be prepared to `COPY` those in. |

**Rule of thumb:** if your binary is statically linked, ship `distroless/static:nonroot`. If it needs libc, ship `distroless/cc`. Reach for `alpine` only when you need a shell or a package at runtime. Reach for `scratch` only when you've measured and proven `distroless/static` is insufficient.

### Minimize layers and keep them small

Every `RUN`, `COPY`, `ADD` creates a layer. Layers are **immutable** — deleting a file in a later layer does not reduce its predecessor's size. The file is still in the image. Consequences:

```dockerfile
# WRONG — the cache is in the image forever
RUN apt-get update && apt-get install -y build-essential
RUN rm -rf /var/lib/apt/lists/*         # does NOT shrink the previous layer

# RIGHT — single layer, cache never committed
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*
```

```dockerfile
# WRONG — secret is in layer history forever
RUN echo "$API_KEY" > /root/.netrc && curl ... && rm /root/.netrc

# RIGHT — see "mount=type=secret" below
RUN --mount=type=secret,id=netrc,target=/root/.netrc curl ...
```

### Standard size-reducers per package manager

| Ecosystem | Command | Effect |
|-----------|---------|--------|
| `apt` | `apt-get install --no-install-recommends` + `rm -rf /var/lib/apt/lists/*` | Skip recommended packages, drop package index. |
| `apk` (Alpine) | `apk add --no-cache` | Don't cache the index. |
| `npm` | `npm ci --omit=dev` (or `npm prune --omit=dev` after build) | Drop dev dependencies from the node_modules you ship. |
| `pip` | `pip install --no-cache-dir` | Don't keep wheel cache. |
| `go` | `-ldflags="-s -w" -trimpath` + `CGO_ENABLED=0` | Strip symbols, trim paths, produce static binary. |
| `dotnet` | `dotnet publish -c Release --no-self-contained -p:PublishTrimmed=true` (or AOT) | Framework-dependent deploys are much smaller than self-contained. |
| `java` | `jlink --add-modules ... --strip-debug --no-man-pages --no-header-files` | Custom JRE with only required modules. |
| `cargo` | `--release` + `strip` + target `musl` for static | Release profile, stripped symbols. |

### Drop artifacts between stages

The primary size win is always **discarding the build stage**. After that, shave the final stage:

```dockerfile
# Go: 800 MB → 5 MB, in one change
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

---

## OPTIMIZATION FOR BUILD TIME

Image size and build time are governed by different rules. Size is about **what ends up in layers**. Build time is about **what gets recomputed vs. cached**.

### Layer order: stable → volatile

Docker layer cache invalidates from the first changed line down. Order instructions from least-likely-to-change to most-likely-to-change.

```dockerfile
# RIGHT — dependency layers cached across source edits
FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./        # rarely changes
RUN npm ci                                    # expensive, now cached

FROM deps AS build
COPY . .                                      # changes every commit
RUN npm run build
```

```dockerfile
# WRONG — every source edit re-runs npm ci
FROM node:22-slim
WORKDIR /app
COPY . .
RUN npm ci && npm run build
```

### Cache mounts — the highest-leverage BuildKit feature

`RUN --mount=type=cache,target=<dir>` gives the `RUN` step a **persistent, build-local cache directory** that is **not** committed to any layer. This transforms package-manager performance:

```dockerfile
# Go module cache + build cache
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /out/app ./cmd/app

# pip wheel cache
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# npm cache
RUN --mount=type=cache,target=/root/.npm \
    npm ci --cache /root/.npm --prefer-offline

# cargo registry + git + build cache
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    cargo build --release

# apt cache (Debian/Ubuntu) — needs rm of the default cleanup hooks
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get install -y --no-install-recommends build-essential

# Maven local repo
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw -B package

# Gradle
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon build
```

The cache survives across builds on the same builder and does **not** land in any layer. Build time drops 50–90 % on incremental rebuilds.

Sharing modes:
- `sharing=shared` (default) — multiple concurrent builds may use the cache at once.
- `sharing=locked` — serialize access (use for `apt`, which corrupts on concurrent writes).
- `sharing=private` — each build gets a fresh cache (rare).

### Bind mounts — avoid the `COPY` dance for build-only inputs

`RUN --mount=type=bind,source=.,target=/src` exposes host files to a `RUN` without a `COPY`. Useful when you only need files transiently:

```dockerfile
RUN --mount=type=bind,source=pom.xml,target=pom.xml \
    --mount=type=bind,source=.mvn,target=.mvn \
    --mount=type=cache,target=/root/.m2 \
    ./mvnw dependency:go-offline
```

### Secret mounts — pass secrets without leaking them into layers

Never `COPY` a secret. Never `--build-arg API_KEY=...` (it stays in image history). Use `--mount=type=secret`:

```dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci
```

Build with:
```bash
docker buildx build --secret id=npmrc,src=$HOME/.npmrc -t myapp .
# or, from env:
docker buildx build --secret id=github_token,env=GITHUB_TOKEN -t myapp .
```

Secrets are mounted into the `RUN` filesystem during that step, never written to any layer, never visible to `docker history`.

### SSH mounts — cloning private git repos during build

```dockerfile
RUN --mount=type=ssh \
    git clone git@github.com:org/private.git /src/private
```

Build with `docker buildx build --ssh default -t myapp .`.

### Cache backends — persist cache across CI runners

Cache mounts persist on the **builder**. In ephemeral CI (GitHub Actions, GitLab runners), each job starts with an empty builder. Fix with a cache backend:

| Backend | Flags | Use when |
|---------|-------|----------|
| **GitHub Actions cache** | `--cache-to type=gha,mode=max --cache-from type=gha` | You're on GitHub Actions. 10 GB per repo, auto-evicted. |
| **Registry** | `--cache-to type=registry,ref=myorg/app:buildcache,mode=max --cache-from type=registry,ref=myorg/app:buildcache` | Portable across CI systems. Uses a dedicated image tag. |
| **Inline** | `--cache-to type=inline --cache-from type=registry,ref=myorg/app:latest` | Simple. Cache metadata is embedded in the pushed image. Cannot cache all stages (only final). |
| **Local filesystem** | `--cache-to type=local,dest=/tmp/buildx-cache --cache-from type=local,src=/tmp/buildx-cache` | Local dev or self-hosted runners with persistent volumes. |
| **S3 / Azure Blob** | `--cache-to type=s3,...` | Large org with centralized cache infra. |

`mode=max` caches all stages (recommended). `mode=min` (default) only caches the final stage.

### Parallel stage execution

BuildKit runs independent stages concurrently automatically. Structure your Dockerfile so unrelated work is in separate stages:

```dockerfile
FROM node:22-slim AS frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build

FROM golang:1.23 AS backend
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /out/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=backend  /out/server        /server
COPY --from=frontend /app/dist          /frontend
ENTRYPOINT ["/server"]
```

`frontend` and `backend` build in parallel. The final stage waits on both. No orchestration needed.

---

## MULTI-ARCHITECTURE BUILDS

### Why

ARM64 is no longer a niche: Apple Silicon (M1/M2/M3/M4) developer laptops, AWS Graviton, Azure Cobalt, Google Axion, Ampere, Raspberry Pi 4/5. If you only ship `linux/amd64`, ARM users either cannot run your image or run it through slow emulation (5–20× slower per published benchmarks).

### How it works — manifest lists

A "multi-arch image" is a **manifest list** (also called an OCI image index): a small JSON document that maps platform tuples (`linux/amd64`, `linux/arm64`, ...) to per-platform image digests. `docker pull myapp:latest` on an arm64 host silently picks the `linux/arm64` manifest. The tag is the same everywhere; the bytes differ per platform.

### One-time setup

```bash
# Verify buildx
docker buildx version

# Install QEMU emulators (handles every arch via binfmt_misc)
docker run --privileged --rm tonistiigi/binfmt --install all

# Create a multi-arch-capable builder (docker-container driver is required)
docker buildx create --name multiarch --driver docker-container --bootstrap
docker buildx use multiarch
docker buildx inspect multiarch
```

The `inspect` output lists supported platforms, typically `linux/amd64, linux/amd64/v2, linux/amd64/v3, linux/arm64, linux/arm/v7, linux/arm/v6, linux/386, linux/ppc64le, linux/s390x, linux/riscv64`.

### Build and push

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myregistry/myapp:1.2.3 \
  --tag myregistry/myapp:latest \
  --push \
  .
```

### The `--push` / `--load` gotcha

> Multi-platform images **cannot** be loaded into the local Docker engine. They exist as manifest lists, and the local engine holds one image per tag.

| Flag | Works with `--platform` multi-value? | Result |
|------|--------------------------------------|--------|
| `--push` | **Yes** | Pushes all platform variants + manifest list to the registry. |
| `--load` | **No** (single platform only) | Loads into local `docker images`. Fails on multi-platform. |
| (neither) | N/A | Built and discarded. Useful for verifying the build works. |

Local testing pattern: build single-platform with `--load`, then multi-platform with `--push`:

```bash
# Local sanity check
docker buildx build --platform linux/arm64 --load -t myapp:dev .

# Release build
docker buildx build --platform linux/amd64,linux/arm64 --push -t myorg/myapp:1.0 .
```

### `TARGETPLATFORM` / `TARGETOS` / `TARGETARCH` / `TARGETVARIANT` / `BUILDPLATFORM`

BuildKit sets these ARGs automatically during multi-platform builds. **They must be declared** (`ARG TARGETOS`) before they can be used.

| ARG | Example value | Meaning |
|-----|---------------|---------|
| `BUILDPLATFORM` | `linux/amd64` | The host running `docker buildx`. |
| `BUILDOS` | `linux` | OS component of `BUILDPLATFORM`. |
| `BUILDARCH` | `amd64` | Arch component of `BUILDPLATFORM`. |
| `TARGETPLATFORM` | `linux/arm64` | The platform this stage is producing an image for. |
| `TARGETOS` | `linux` | OS component of `TARGETPLATFORM`. |
| `TARGETARCH` | `arm64` | Arch component of `TARGETPLATFORM`. |
| `TARGETVARIANT` | `v7` (for `linux/arm/v7`), empty for arm64 | Sub-arch variant. |

Use them to download arch-specific binaries or drive cross-compilers:

```dockerfile
FROM alpine:3.20
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64) URL=https://example.com/tool-linux-x86_64.tar.gz ;; \
      arm64) URL=https://example.com/tool-linux-aarch64.tar.gz ;; \
      *)     echo "unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && wget -qO- "$URL" | tar -xz -C /usr/local/bin
```

### The `FROM --platform=$BUILDPLATFORM` cross-compile pattern (HIGHEST-LEVERAGE TRICK)

QEMU emulation is slow (5–20×). When the compiler itself supports cross-compilation (Go, Rust with cross targets, .NET, Zig, any `GOOS`/`GOARCH`-aware toolchain), run the **build stage natively** on `$BUILDPLATFORM` and produce binaries **for** `$TARGETPLATFORM`. The final stage still runs on `$TARGETPLATFORM` because it only contains the binary, not a compiler.

```dockerfile
# syntax=docker/dockerfile:1.9

# Build natively on the host arch (no QEMU), cross-compile to the target.
FROM --platform=$BUILDPLATFORM golang:1.23 AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

# Runtime stage runs on $TARGETPLATFORM (no override needed — it's implicit).
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

Result: multi-arch build time approaches single-arch time, because the slow part (the compiler) runs natively.

For languages without a native cross-compiler (e.g. C-heavy Python wheels, native-module Node), you have two options:
1. Accept QEMU emulation (simple, slow).
2. Parallel per-arch CI jobs on native runners, then merge manifests (fast, more pipeline complexity — see [CI pattern](#ci-patterns) below).

### Inspecting a multi-arch image

```bash
docker buildx imagetools inspect myregistry/myapp:latest
```

Sample output:

```
Name:      myregistry/myapp:latest
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:abc123...

Manifests:
  Name:      myregistry/myapp:latest@sha256:def456...
  Platform:  linux/amd64
  Name:      myregistry/myapp:latest@sha256:ghi789...
  Platform:  linux/arm64
```

To pull/run a specific arch:

```bash
docker pull --platform linux/arm64 myregistry/myapp:latest
docker run  --platform linux/arm64 myregistry/myapp:latest
```

### CI patterns

#### GitHub Actions — single-job multi-arch (simple)

```yaml
name: image
on:
  push: { branches: [main], tags: ['v*'] }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

#### GitHub Actions — per-arch native runners + manifest merge (fast, no QEMU)

Use when QEMU emulation is too slow (e.g. native Python wheels, C extensions). Requires arm64 runners (GitHub-hosted or self-hosted):

```yaml
jobs:
  build:
    strategy:
      matrix:
        include:
          - arch: amd64
            runner: ubuntu-latest
          - arch: arm64
            runner: ubuntu-24.04-arm   # GitHub native arm64 runner
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with: { registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }} }
      - uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/${{ matrix.arch }}
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}-${{ matrix.arch }}
          cache-from: type=gha,scope=${{ matrix.arch }}
          cache-to: type=gha,mode=max,scope=${{ matrix.arch }}

  merge:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: docker/login-action@v3
        with: { registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }} }
      - name: Create manifest list
        run: |
          docker buildx imagetools create \
            --tag ghcr.io/${{ github.repository }}:latest \
            --tag ghcr.io/${{ github.repository }}:${{ github.sha }} \
            ghcr.io/${{ github.repository }}:${{ github.sha }}-amd64 \
            ghcr.io/${{ github.repository }}:${{ github.sha }}-arm64
```

#### GitLab CI — single-job multi-arch

```yaml
build:
  image: docker:24
  services: [docker:24-dind]
  variables: { DOCKER_TLS_CERTDIR: "/certs" }
  before_script:
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    - docker run --privileged --rm tonistiigi/binfmt --install all
    - docker buildx create --use --name multiarch
  script:
    - docker buildx build
      --platform linux/amd64,linux/arm64
      --tag "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"
      --tag "$CI_REGISTRY_IMAGE:latest"
      --cache-to   "type=registry,ref=$CI_REGISTRY_IMAGE:buildcache,mode=max"
      --cache-from "type=registry,ref=$CI_REGISTRY_IMAGE:buildcache"
      --push .
```

---

## .DOCKERIGNORE

`.dockerignore` is not optional. It drives:

1. **Build speed** — `COPY . .` and `COPY --from` only see un-ignored paths. Less to hash, less to invalidate cache on.
2. **Size** — ignored files never enter any layer.
3. **Security** — `.git/`, `.env`, `id_rsa`, `.aws/credentials` stay out of images.
4. **Cache correctness** — if `node_modules/` is not ignored, every local `npm install` invalidates `COPY . .`, defeating the dependency layer.

### Minimum baseline

```gitignore
# VCS
.git
.gitignore
.github/
.gitlab-ci.yml

# Editor / OS
.idea/
.vscode/
.DS_Store
*.swp

# Secrets / env
.env
.env.*
!.env.example
*.pem
*.key
id_rsa*

# Dependency caches and build outputs (will be rebuilt inside the image)
node_modules/
bower_components/
__pycache__/
*.pyc
.venv/
venv/
target/
dist/
build/
out/
bin/
obj/
.next/
.nuxt/
.cache/

# Test artifacts
coverage/
.coverage
.pytest_cache/
.tox/
*.log

# Docker itself
Dockerfile*
.dockerignore
docker-compose*.yml

# Docs — rebuild outside the image pipeline
README.md
CHANGELOG.md
docs/
```

The `Dockerfile*` entry looks paradoxical but is correct: the Dockerfile is read by the daemon directly, not as part of the build context. Excluding it from context trims the upload.

### Language-specific additions

- **Go**: `vendor/` only if you use modules without vendoring. If you commit `vendor/`, **do not ignore it** — you'll break offline builds.
- **Python**: `*.egg-info/`, `.mypy_cache/`, `.ruff_cache/`.
- **.NET**: `bin/`, `obj/`, `*.user`, `TestResults/`.
- **Rust**: `target/` (usually).
- **Java**: `target/`, `.gradle/`, `build/`.

---

## SECURITY HARDENING

### Run as non-root

Always declare a non-root `USER` in the final stage. Even if the container escapes, a non-root process limits blast radius.

```dockerfile
# Preferred: use a base that ships a non-root user (distroless "nonroot" tag)
FROM gcr.io/distroless/static-debian12:nonroot
USER nonroot:nonroot

# Otherwise: create one
FROM debian:bookworm-slim
RUN groupadd --system --gid 1000 app \
 && useradd --system --uid 1000 --gid app --no-create-home --shell /sbin/nologin app
USER app:app
```

`USER` accepts `<uid>:<gid>` or `<name>:<group>`. Numeric UIDs are preferred for Kubernetes `runAsNonRoot: true` checks — the admission controller can verify UID ≠ 0 without resolving `/etc/passwd`.

### Don't run as root even during `RUN` steps you can avoid

The final `USER` directive also governs `CMD`/`ENTRYPOINT`. Install packages, compile, etc. **as root**; switch to non-root **only** before `ENTRYPOINT`.

### Use `COPY`, not `ADD`

`ADD` has surprise behavior: auto-extracts local tarballs, fetches remote URLs with no checksum verification. Use `COPY` unless you specifically need one of those. For remote files, `RUN curl ... && echo "$SHA sum.tar.gz" | sha256sum -c` is safer.

### Pin base images by digest (see prologue)

```dockerfile
FROM golang:1.23@sha256:abcdef... AS build
FROM gcr.io/distroless/static-debian12:nonroot@sha256:123456...
```

### Minimize the final stage

- No shell = no `docker exec` into a compromised container. Distroless provides this by default.
- No package manager = no ability to install attacker tools post-exploit.
- No SUID binaries. (Distroless has none.)

### Don't bake secrets into layers

- `ARG` values are visible in `docker history` and `docker inspect`. Never pass secrets via `--build-arg`.
- Use `--mount=type=secret` (see Build-Time Optimization).
- If you must use an env var at runtime, inject it via the orchestrator (`kubectl set env`, `docker run -e`, a secrets manager), never a baked `ENV SECRET=...`.

### Drop write capabilities with `--read-only`

Build images that tolerate being run with `docker run --read-only`. Put writable paths (logs, temp) on tmpfs volumes at runtime. The Dockerfile side is: don't assume `/` is writable; put caches under `/tmp` (tmpfs-able) or a declared `VOLUME`.

---

## RUNTIME HYGIENE

### `HEALTHCHECK`

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:8080/healthz || exit 1
```

For distroless (no `curl`, no shell): ship a tiny healthcheck binary with the app, or point Kubernetes `livenessProbe` at an HTTP endpoint instead (Kubernetes doesn't need Dockerfile `HEALTHCHECK`).

### `ENTRYPOINT` vs `CMD`

- **Exec form** (JSON array) only: `ENTRYPOINT ["/app"]`, `CMD ["--flag"]`. Shell form (`ENTRYPOINT /app`) wraps in `/bin/sh -c`, which doesn't exist in distroless, doesn't forward signals, and is an anti-pattern.
- `ENTRYPOINT` = the binary. `CMD` = default arguments. Users can override `CMD` with `docker run myapp --debug` without rewriting the entrypoint.
- Containers must forward `SIGTERM` to the app for graceful shutdown. The exec form does this; the shell form does not. If your app is PID 1, it receives `SIGTERM` directly — handle it. If you use an init (tini, dumb-init), that's fine too.

### `STOPSIGNAL`

If the app expects a signal other than `SIGTERM` (e.g. nginx wants `SIGQUIT` for graceful shutdown):
```dockerfile
STOPSIGNAL SIGQUIT
```

### `EXPOSE` is documentation only

`EXPOSE 8080` does not open a port. It's a hint for tools (`docker run -P` uses it; compose doesn't). Document the port with it but don't rely on it for networking.

### `WORKDIR`, not `cd`

`RUN cd /app && ...` creates a new shell per `RUN`, so `cd` doesn't persist. Use `WORKDIR /app`.

### `ENV` vs `ARG`

- `ARG` is build-time, dies at end of stage (unless re-declared in the next stage — `ARG` scope is per-stage).
- `ENV` is runtime; persists into the final image. Use for defaults (`ENV NODE_ENV=production`). Never for secrets.

---

## PER-LANGUAGE TEMPLATES

Each template assumes BuildKit, multi-stage, multi-arch-ready (`$BUILDPLATFORM` cross-compile where the language supports it), distroless or minimal final stage, non-root runtime.

### Go

```dockerfile
# syntax=docker/dockerfile:1.9
FROM --platform=$BUILDPLATFORM golang:1.23 AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

**Notes.** `CGO_ENABLED=0` produces a static binary that runs on `distroless/static` or `scratch`. If you need CGO (sqlite, OpenSSL bindings), use `distroless/cc` and drop the `--platform=$BUILDPLATFORM` trick (cross-CGO is painful; use native runners in CI).

### Node.js / TypeScript

```dockerfile
# syntax=docker/dockerfile:1.9
FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

FROM node:22-slim AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build \
 && npm prune --omit=dev

FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./
USER nonroot
CMD ["dist/server.js"]
```

**Notes.** `distroless/nodejs22` provides Node + libc + CA certs and nothing else. `npm prune --omit=dev` removes devDependencies after build. For monorepos (pnpm workspaces, Turbo), adjust the `COPY` scope but keep the structure.

### Python

```dockerfile
# syntax=docker/dockerfile:1.9
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

FROM base AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pyproject.toml requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m venv /venv \
 && /venv/bin/pip install --upgrade pip \
 && /venv/bin/pip install -r requirements.txt
COPY . .
# Optional: pre-compile bytecode for faster cold start
RUN /venv/bin/python -m compileall -q .

FROM base AS runtime
RUN groupadd --system --gid 1000 app \
 && useradd --system --uid 1000 --gid app --no-create-home app
WORKDIR /app
COPY --from=build /venv /venv
COPY --from=build /app /app
ENV PATH="/venv/bin:$PATH"
USER app:app
ENTRYPOINT ["python", "-m", "app"]
```

**Notes.** A virtualenv at `/venv` is the cleanest way to ship Python — one `COPY`, deterministic paths. `build-essential` lives only in the build stage. For native wheels across architectures, QEMU is typically unavoidable — consider per-arch CI runners. For `uv`/`poetry`, swap the install command but keep the venv-copy pattern.

### .NET

```dockerfile
# syntax=docker/dockerfile:1.9
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG TARGETARCH
WORKDIR /src
COPY *.sln ./
COPY src/MyApp/*.csproj src/MyApp/
RUN dotnet restore src/MyApp/MyApp.csproj -a $TARGETARCH
COPY . .
RUN dotnet publish src/MyApp/MyApp.csproj \
    -c Release \
    -a $TARGETARCH \
    --no-restore \
    --no-self-contained \
    -o /out

FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy-chiseled AS runtime
WORKDIR /app
COPY --from=build /out .
USER $APP_UID
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

**Notes.** `-a $TARGETARCH` drives .NET's RID (`linux-x64` / `linux-arm64`) cross-compile — analogous to Go's `GOARCH`. `-chiseled` base images are Microsoft's distroless equivalent; `$APP_UID` (= 1654) is a predefined non-root user. Framework-dependent (`--no-self-contained`) is significantly smaller than self-contained; switch to self-contained + AOT only when startup latency matters more than size.

### Rust

```dockerfile
# syntax=docker/dockerfile:1.9
FROM --platform=$BUILDPLATFORM rust:1.82 AS build
ARG TARGETPLATFORM
RUN case "$TARGETPLATFORM" in \
      linux/amd64) echo x86_64-unknown-linux-musl  > /tmp/target ;; \
      linux/arm64) echo aarch64-unknown-linux-musl > /tmp/target ;; \
      *) echo "unsupported: $TARGETPLATFORM" && exit 1 ;; \
    esac \
 && rustup target add "$(cat /tmp/target)" \
 && apt-get update && apt-get install -y --no-install-recommends musl-tools \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    cargo build --release --target "$(cat /tmp/target)" \
 && cp target/$(cat /tmp/target)/release/myapp /out

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

**Notes.** `musl` target produces a fully static binary, so `distroless/static` works. For glibc dynamic linking, drop `musl` and target `distroless/cc`.

### Java (Spring Boot, JLink custom JRE)

```dockerfile
# syntax=docker/dockerfile:1.9
FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /src
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -DskipTests package \
 && cp target/*.jar /out.jar

FROM eclipse-temurin:21-jre-jammy AS runtime
RUN groupadd --system --gid 1000 app \
 && useradd --system --uid 1000 --gid app --no-create-home app
WORKDIR /app
COPY --from=build /out.jar ./app.jar
USER app:app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

**Notes.** For stricter slimming, swap the runtime for a `jlink` custom JRE + `gcr.io/distroless/java-base`. Consider `Jib` (Maven/Gradle plugin) before hand-rolling a Dockerfile — it produces reproducible, layer-optimized images without a Dockerfile at all.

### Static site (nginx)

```dockerfile
# syntax=docker/dockerfile:1.9
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --prefer-offline
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine-slim
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
# nginx-unprivileged listens on 8080 and runs as uid 101 by default
EXPOSE 8080
```

---

## ANTI-PATTERNS

| Anti-pattern | Why it's wrong | Fix |
|--------------|----------------|-----|
| Single-stage Dockerfile for a compiled language | Ships the toolchain to production | Multi-stage: build in one stage, `COPY --from=build` into a minimal runtime |
| `FROM latest` or bare tag in production | Non-reproducible, supply-chain blind | Pin by digest (`@sha256:...`) |
| Missing `.dockerignore` | Slow builds, cache defeated by local `node_modules`, secrets leaked | Ship one with every Dockerfile |
| `ADD https://...` for remote files | No checksum verification | `RUN curl ... && echo "$SHA $FILE" \| sha256sum -c` |
| `--build-arg API_KEY=$SECRET` | ARG values land in `docker history` and image metadata | `--mount=type=secret` |
| Running as root in the final stage | Container-escape = host root | `USER` with a non-root uid, prefer `distroless:nonroot` |
| `RUN apt-get install` without `rm -rf /var/lib/apt/lists/*` | Package index bloats the layer | Combine into one `RUN ... && rm -rf ...`, or use a cache mount |
| `apt-get install` without `--no-install-recommends` | Pulls extra packages | Always pass `--no-install-recommends` |
| `COPY . .` before `COPY package.json && npm ci` | Cache invalidates on every source edit | Copy dependency manifests first, install, then copy source |
| Multiple `RUN apt-get update`s | Each is its own layer; the first may have stale indices by the time the second runs | One `RUN apt-get update && apt-get install -y ...` |
| `RUN cd /app && make` | Shell exits after `RUN`; `cd` is wasted | `WORKDIR /app` + `RUN make` |
| Shell-form `ENTRYPOINT /app` | Wraps in `sh -c`, breaks signal forwarding, doesn't exist in distroless | Exec form: `ENTRYPOINT ["/app"]` |
| Single-platform image pushed to a multi-arch registry tag | ARM users get amd64 via emulation (or can't pull) | `docker buildx build --platform linux/amd64,linux/arm64 --push` |
| Running the compiler under QEMU for multi-arch | 5–20× slower than native | `FROM --platform=$BUILDPLATFORM` + cross-compile toolchain |
| `docker buildx build --load` with multiple platforms | Fails — local engine can't hold a manifest list | Use `--push`, or build one platform at a time for local `--load` |
| No `HEALTHCHECK` on a long-running service | Orchestrator can't detect wedged processes | Add `HEALTHCHECK` or a Kubernetes `livenessProbe` |
| `RUN pip install ... && rm -rf /root/.cache/pip` | Still a layer; cache is committed and then shadowed | `RUN --mount=type=cache,target=/root/.cache/pip pip install ...` |
| `COPY --from=0` (integer stage reference) | Breaks silently on reordering | `COPY --from=<name>` with `AS <name>` |

---

## AUTHORING QUICK REFERENCE

```dockerfile
# syntax=docker/dockerfile:1.9        # line 1, always

# --- Build stage (runs on host arch, cross-compiles to target) ---
FROM --platform=$BUILDPLATFORM <base>:<tag>@sha256:<digest> AS build
ARG TARGETOS TARGETARCH

WORKDIR /src
# 1. Copy dependency manifests
COPY <lockfiles> ./
# 2. Install deps with cache mount
RUN --mount=type=cache,target=<cache-dir> <install-command>
# 3. Copy source
COPY . .
# 4. Build with cache mount + cross-compile args
RUN --mount=type=cache,target=<cache-dir> <build-command>

# --- Runtime stage ---
FROM <minimal-base>:<tag>@sha256:<digest>
COPY --from=build /out/app /app
USER <non-root-user>
HEALTHCHECK CMD <probe>
ENTRYPOINT ["/app"]
```

### Build commands

```bash
# Local sanity check (single platform, load into local Docker)
docker buildx build --load -t myapp:dev .

# Single-platform with cache
docker buildx build \
  --cache-from type=gha --cache-to type=gha,mode=max \
  --load -t myapp:dev .

# Multi-arch release (must --push)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --cache-from type=registry,ref=myorg/myapp:buildcache \
  --cache-to   type=registry,ref=myorg/myapp:buildcache,mode=max \
  --tag myorg/myapp:1.2.3 \
  --tag myorg/myapp:latest \
  --push .

# Inspect manifest list
docker buildx imagetools inspect myorg/myapp:latest

# Build and run a single stage (test target)
docker buildx build --target test --load -t myapp:test . \
  && docker run --rm myapp:test
```

### Secret injection (build time)

```bash
docker buildx build --secret id=npmrc,src=$HOME/.npmrc -t myapp .
docker buildx build --secret id=github_token,env=GITHUB_TOKEN -t myapp .
```

```dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

---

## VERIFICATION CHECKLIST (BEFORE DECLARING DONE)

Run through this list every time you finish a Dockerfile. If any item fails, iterate.

- [ ] First line is `# syntax=docker/dockerfile:1.<N>`.
- [ ] Build is multi-stage (if the app has a build step).
- [ ] Every stage is named with `AS <name>`; no integer `--from=0` references.
- [ ] Base images are pinned by digest for production Dockerfiles (tag acceptable for dev/local-only).
- [ ] A `.dockerignore` exists alongside the Dockerfile and excludes `.git`, `.env`, dependency caches, and build outputs.
- [ ] Dependency manifests are copied **before** source, and installed with a cache mount.
- [ ] Package-manager caches are cleaned or placed on `--mount=type=cache`.
- [ ] No secrets in `ARG` / `ENV` / `RUN echo "$SECRET" > ...`. Use `--mount=type=secret`.
- [ ] Final stage uses distroless, alpine, or a slim base — never the full builder image.
- [ ] Final stage declares `USER <non-root>`.
- [ ] `ENTRYPOINT` / `CMD` use exec form (JSON array), not shell form.
- [ ] Long-running services declare `HEALTHCHECK` (or delegate to a Kubernetes probe).
- [ ] For multi-arch: `FROM --platform=$BUILDPLATFORM` is used on build stages where the toolchain supports cross-compilation.
- [ ] `ARG TARGETOS TARGETARCH` (or `TARGETPLATFORM`) is **declared** before use.
- [ ] Build tested with `docker buildx build --platform linux/amd64,linux/arm64 --push` (or single-platform `--load` locally).
- [ ] `docker buildx imagetools inspect <image>` shows all expected platform manifests.
- [ ] Image scanned (`trivy image`, `grype`, or `docker scout`) with no CRITICAL vulnerabilities introduced by this change.
- [ ] Image size measured before/after — non-trivial regressions justified.
- [ ] Container runs end-to-end: `docker run --rm <image>` exits cleanly or serves traffic as expected.
