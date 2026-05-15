---
name: docker-compose-patterns
description: MUST USE when setting up local development environments with Docker Compose — multi-service orchestration, healthchecks, volumes, networking, profiles, environment management, and production-ready patterns.
license: BSD-3-Clause
compatibility: opencode
metadata:
  domain: platform-engineering
  tool: docker-compose
  pattern: local-development
---

# Docker Compose Patterns

Reference for Docker Compose v2 (Go-based `docker compose` CLI). All examples follow the
[Compose Specification](https://github.com/compose-spec/compose-spec).

---

## 1. Service Definition Patterns

### Build from local Dockerfile

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      APP_ENV: development
```

### Use a prebuilt image

```yaml
services:
  api:
    image: myorg/api:1.5.2
    ports:
      - "8000:8000"
```

### Environment variables — map vs list

```yaml
services:
  api:
    environment:                  # map syntax (preferred)
      DATABASE_URL: postgres://db:5432/app
      DEBUG: "true"

  worker:
    environment:                  # list syntax
      - DATABASE_URL=postgres://db:5432/app
      - DEBUG=true
```

### Port mapping patterns

```yaml
services:
  web:
    ports:
      - "3000:3000"              # host:container — same port
      - "8080:80"                # host 8080 → container 80
      - "127.0.0.1:9090:9090"   # bind to localhost only
      - "5432"                   # random host port → container 5432
    expose:
      - "9090"                   # internal only — no host mapping
```

---

## 2. Healthcheck Patterns

### HTTP healthcheck

```yaml
services:
  api:
    image: myorg/api:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
      start_interval: 3s        # faster checks during startup
```

### TCP healthcheck (no curl needed)

```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
```

### Command-based healthcheck

```yaml
services:
  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
```

### Disable inherited healthcheck

```yaml
services:
  worker:
    image: myorg/api:latest
    healthcheck:
      disable: true
```

---

## 3. Volume Patterns

### Named volumes (data persistence across recreates)

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:                        # managed by Docker
```

### Bind mounts (live code reload)

```yaml
services:
  api:
    build: .
    volumes:
      - ./src:/app/src            # host dir → container dir
      - ./config:/app/config:ro   # read-only bind mount
```

### Anonymous volume for node_modules isolation

```yaml
services:
  app:
    build: .
    volumes:
      - .:/app                   # bind mount entire project
      - /app/node_modules         # anonymous volume — prevents host override
```

---

## 4. Networking

### Custom networks with service discovery

```yaml
services:
  api:
    networks:
      - backend
      - frontend

  db:
    networks:
      - backend                   # not reachable from frontend network

  nginx:
    networks:
      - frontend

networks:
  frontend:
  backend:
```

Services resolve each other by service name within the same network:
`postgres://db:5432/app` — `db` resolves automatically.

### Network aliases

```yaml
services:
  api:
    networks:
      backend:
        aliases:
          - app-server
          - api-v2
```

### Host networking (Linux only)

```yaml
services:
  agent:
    image: monitoring-agent:latest
    network_mode: host
```

---

## 5. Multi-Stage Development (Profiles)

```yaml
services:
  api:
    build: .
    ports:
      - "8000:8000"
    # no profiles → always starts

  db:
    image: postgres:16
    profiles: []                  # always starts (explicit)

  worker:
    image: myorg/worker:latest
    profiles: ["worker"]          # only with --profile worker

  test-runner:
    build:
      context: .
      target: test
    profiles: ["test"]

  seed:
    build:
      context: .
      target: seed
    profiles: ["seed"]
    depends_on:
      db:
        condition: service_healthy

  monitoring:
    image: grafana/grafana:latest
    profiles: ["monitoring", "prod"]

  prometheus:
    image: prom/prometheus:latest
    profiles: ["monitoring", "prod"]
```

Usage:

```bash
docker compose up                              # api + db only
docker compose --profile worker up             # api + db + worker
docker compose --profile test run test-runner   # run tests
docker compose --profile monitoring up          # api + db + grafana + prometheus
```

---

## 6. Environment Management

### `.env` file (auto-loaded from project root)

```dotenv
# .env
POSTGRES_PASSWORD=secret
APP_PORT=8000
IMAGE_TAG=latest
```

```yaml
services:
  api:
    image: myorg/api:${IMAGE_TAG}
    ports:
      - "${APP_PORT}:8000"
```

### `env_file` directive

```yaml
services:
  api:
    env_file:
      - .env                     # always loaded
      - path: .env.local         # optional override
        required: false
```

### Variable interpolation with defaults

```yaml
services:
  api:
    image: myorg/api:${IMAGE_TAG:-latest}             # default if unset
    environment:
      LOG_LEVEL: ${LOG_LEVEL:?LOG_LEVEL must be set}   # error if unset
      DB_HOST: ${DB_HOST:-db}                          # fallback
```

### Override files

```bash
# docker compose automatically merges:
#   compose.yaml + compose.override.yaml

# explicit overrides:
docker compose -f compose.yaml -f compose.prod.yaml up
```

```yaml
# compose.override.yaml — dev-only overrides
services:
  api:
    build: .                     # build from source instead of using image
    volumes:
      - ./src:/app/src           # live reload
    environment:
      DEBUG: "true"
```

---

## 7. Common Service Templates

### PostgreSQL

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-secret}
      POSTGRES_DB: app_db
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app_db"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

### Redis

```yaml
services:
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD:-redis}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-redis}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  redis_data:
```

### RabbitMQ

```yaml
services:
  rabbitmq:
    image: rabbitmq:3-management-alpine
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    ports:
      - "5672:5672"
      - "15672:15672"            # management UI
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  rabbitmq_data:
```

### Kafka (KRaft — no Zookeeper)

```yaml
services:
  kafka:
    image: apache/kafka:3.8.0
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"
    ports:
      - "9092:9092"
    volumes:
      - kafka_data:/var/lib/kafka/data
    healthcheck:
      test: ["CMD-SHELL", "/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 30s

volumes:
  kafka_data:
```

### Elasticsearch (single-node dev)

```yaml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.14.0
    environment:
      discovery.type: single-node
      xpack.security.enabled: "false"
      ES_JAVA_OPTS: "-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  es_data:
```

---

## 8. Dependency Ordering

### depends_on with health conditions

```yaml
services:
  api:
    build: .
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      migrations:
        condition: service_completed_successfully

  migrations:
    build:
      context: .
      target: migrations
    command: ["python", "manage.py", "migrate"]
    depends_on:
      db:
        condition: service_healthy

  worker:
    build: .
    command: ["celery", "-A", "app", "worker"]
    depends_on:
      api:
        condition: service_started       # don't wait for healthy
        restart: true                    # restart worker if api restarts
      redis:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      timeout: 3s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
```

### Optional dependencies

```yaml
services:
  api:
    depends_on:
      telemetry:
        condition: service_started
        required: false           # api starts even if telemetry is absent
```

---

## 9. Build Patterns

### Multi-stage with target

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: development         # stop at 'development' stage
    volumes:
      - ./src:/app/src

  api-prod:
    build:
      context: .
      target: production
    profiles: ["prod"]
```

### BuildKit cache mounts

```dockerfile
# Dockerfile
FROM python:3.12-slim AS base
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

```yaml
services:
  api:
    build:
      context: .
      cache_from:
        - type=registry,ref=myorg/api:buildcache
      cache_to:
        - type=registry,ref=myorg/api:buildcache,mode=max
```

### Build arguments

```yaml
services:
  api:
    build:
      context: .
      args:
        PYTHON_VERSION: "3.12"
        INSTALL_DEV: "true"
```

### Multi-platform build

```yaml
services:
  api:
    build:
      context: .
      platforms:
        - linux/amd64
        - linux/arm64
```

---

## 10. Debugging Patterns

### Logs

```bash
docker compose logs                     # all services
docker compose logs api                 # single service
docker compose logs -f api worker       # follow multiple services
docker compose logs --since 5m api      # last 5 minutes
docker compose logs --tail 100 api      # last 100 lines
```

### Interactive shell into running container

```bash
docker compose exec api bash            # attach to running container
docker compose exec -u root api sh      # as root
docker compose exec db psql -U app      # run a specific command
```

### Run a one-off command (new container)

```bash
docker compose run --rm api python manage.py shell
docker compose run --rm -e DEBUG=true api pytest
docker compose run --rm --no-deps api bash   # skip dependencies
```

### Inspect service state

```bash
docker compose ps                       # list running services
docker compose ps -a                    # include stopped
docker compose top                      # processes per container
docker compose config                   # validate and print resolved config
docker compose config --services        # list service names
```


---

## 11. Performance Patterns

### Resource limits

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
          pids: 100
        reservations:
          cpus: "0.25"
          memory: 128M
```

### GPU access

```yaml
services:
  ml-worker:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### Restart policies

```yaml
services:
  api:
    restart: unless-stopped       # always | on-failure | no | unless-stopped

  worker:
    restart: on-failure           # restart only on non-zero exit
```

### Logging limits

```yaml
services:
  api:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

### Init process (reap zombies)

```yaml
services:
  api:
    init: true                    # uses tini as PID 1
```

---

## 12. CI/CD Integration Patterns

### Run tests in CI

```bash
# Start deps, run tests, tear down
docker compose -f compose.yaml -f compose.test.yaml run --rm --exit-code-from test-runner test-runner
docker compose down -v
```

```yaml
# compose.test.yaml
services:
  test-runner:
    build:
      context: .
      target: test
    environment:
      DATABASE_URL: postgres://app:secret@db:5432/test_db
    depends_on:
      db:
        condition: service_healthy
    command: ["pytest", "--tb=short", "-q"]
```

### Build and push in CI

```bash
docker compose build
docker compose push                     # pushes all services with `image:` set
```

### Wait for healthy services

```bash
docker compose up -d
docker compose wait db                  # blocks until db is healthy (Compose v2.29+)
```

### Cleanup

```bash
docker compose down                     # stop and remove containers + default network
docker compose down -v                  # also remove named volumes
docker compose down --rmi all           # also remove images
docker compose down --remove-orphans    # remove containers for undefined services
```

---

## 13. Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `depends_on: [db]` without condition | Service starts before DB is ready | Use `condition: service_healthy` |
| Bind-mounting `node_modules` | Host modules overwrite container's | Add anonymous volume `/app/node_modules` |
| `restart: always` in dev | Hides crash loops | Use `restart: no` or `on-failure` locally |
| Hardcoded secrets in `compose.yaml` | Secrets leak into version control | Use `.env` + `.gitignore`, or Docker secrets |
| `network_mode: host` everywhere | Port conflicts, no isolation | Use custom bridge networks |
| No healthchecks | `depends_on` can't wait for readiness | Always add healthchecks to infrastructure services |
| Using `latest` tag | Non-reproducible builds | Pin explicit version tags |
| `volumes: [.:/app]` without `.dockerignore` | Copies `.git`, `node_modules`, etc. | Create proper `.dockerignore` |
| Giant monolithic compose file | Hard to maintain, slow to start | Split with profiles or multiple compose files |
| Missing `--rm` on `docker compose run` | Leaves stopped containers behind | Always use `--rm` for one-off commands |
| No resource limits | Single service can OOM the host | Set `deploy.resources.limits` |
| Polling for service readiness in entrypoint | Fragile, duplicates compose logic | Use `depends_on` + `condition: service_healthy` |

---

## 14. Quick Reference

### File naming (loaded in order of precedence)

| File | Purpose |
|---|---|
| `compose.yaml` | Primary config (preferred name) |
| `compose.override.yaml` | Auto-merged dev overrides |
| `docker-compose.yml` | Legacy name (still supported) |
| `.env` | Auto-loaded env vars for interpolation |

### Essential commands

| Command | Description |
|---|---|
| `docker compose up -d` | Start all services detached |
| `docker compose up --build` | Rebuild images before starting |
| `docker compose down -v` | Stop, remove containers and volumes |
| `docker compose ps` | List running services |
| `docker compose logs -f <svc>` | Follow logs for a service |
| `docker compose exec <svc> sh` | Shell into running container |
| `docker compose run --rm <svc> <cmd>` | One-off command in new container |
| `docker compose config` | Validate and resolve compose file |
| `docker compose pull` | Pull latest images |
| `docker compose build --no-cache` | Full rebuild without cache |
| `docker compose restart <svc>` | Restart a single service |
| `docker compose stop` | Stop without removing |
| `docker compose wait <svc>` | Block until service is healthy |
| `docker compose watch` | Auto-rebuild/sync on file changes |
| `docker compose alpha dry-run <cmd>` | Preview what a command would do |

### Formats

- **Duration:** `500ms`, `30s`, `5m`, `1h`, `1m30s`
- **Bytes:** `512b`, `1kb`, `10m`, `1g`, `2gb`

### `docker compose watch` (v2.22+)

```yaml
services:
  api:
    build: .
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
        - action: rebuild
          path: ./requirements.txt
        - action: sync+restart
          path: ./config
          target: /app/config
```

Replaces bind mounts for dev hot-reload with better performance and cross-platform support.
