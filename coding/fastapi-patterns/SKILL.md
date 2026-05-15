---
name: fastapi-patterns
description: MUST USE when building FastAPI applications — advanced dependency injection, middleware, background tasks, WebSockets, lifespan events, custom exception handlers, and testing patterns. Covers patterns beyond basic CRUD.
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: python
  framework: fastapi
  pattern: advanced-patterns
---

# FastAPI Advanced Patterns

> Reference: FastAPI 0.136.1 — Python 3.11+
> Style: Google Python Style Guide. Type hints everywhere. `Annotated` preferred.

---

## 1. Advanced Dependency Injection

### 1.1 Nested Dependencies

```python
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, status

app = FastAPI()


def get_db_session() -> "AsyncSession":
    """Yield a database session."""
    db = AsyncSession(engine)
    try:
        yield db
    finally:
        await db.close()


def get_current_user(
    db: Annotated["AsyncSession", Depends(get_db_session)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Resolve user from token — depends on db session."""
    user = db.query(User).filter(User.token == token).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return user


def get_active_user(
    user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Chain: oauth2_scheme -> get_current_user -> get_active_user."""
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
    return user


@app.get("/me")
async def read_me(user: Annotated[User, Depends(get_active_user)]) -> UserOut:
    return user
```

### 1.2 Yield Dependencies (Resource Lifecycle)

```python
from collections.abc import AsyncGenerator
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker


async def get_db(
    session_factory: async_sessionmaker[AsyncSession],
) -> AsyncGenerator[AsyncSession, None]:
    """Yield a transactional session; rollback on error, always close."""
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
```

### 1.3 Class-Based Dependencies

```python
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Query


@dataclass
class PaginationParams:
    """Reusable pagination dependency — use as Depends(PaginationParams)."""

    offset: int = Query(default=0, ge=0)
    limit: int = Query(default=20, ge=1, le=100)


@dataclass
class CommonFilters:
    """Composable filter dependency."""

    q: str | None = Query(default=None, min_length=1, max_length=200)
    sort_by: str = Query(default="created_at")
    order: str = Query(default="desc", pattern="^(asc|desc)$")


@app.get("/items")
async def list_items(
    pagination: Annotated[PaginationParams, Depends()],
    filters: Annotated[CommonFilters, Depends()],
) -> list[ItemOut]:
    return await Item.find(filters, pagination)
```

### 1.4 Dependency Overrides for Testing

```python
from fastapi.testclient import TestClient


def get_db_override() -> FakeDB:
    return FakeDB()


app.dependency_overrides[get_db] = get_db_override

with TestClient(app) as client:
    response = client.get("/items")
    assert response.status_code == 200

# Always clean up
app.dependency_overrides.clear()
```

---

## 2. Middleware Patterns

### 2.1 CORS

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com"],
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Authorization", "Content-Type"],
    allow_credentials=True,
    max_age=3600,
)
```

### 2.2 Request Timing Middleware

```python
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response


class TimingMiddleware(BaseHTTPMiddleware):
    """Add X-Process-Time header to every response."""

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        elapsed_ms = (time.perf_counter() - start) * 1000
        response.headers["X-Process-Time-Ms"] = f"{elapsed_ms:.2f}"
        return response


app.add_middleware(TimingMiddleware)
```

### 2.3 Request ID Middleware

```python
class RequestIDMiddleware(BaseHTTPMiddleware):
    """Inject a unique request ID into every request/response cycle."""

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
```

### 2.4 Pure ASGI Middleware (Better Performance)

```python
from starlette.types import ASGIApp, Receive, Scope, Send


class PureASGITimingMiddleware:
    """Pure ASGI middleware — avoids BaseHTTPMiddleware overhead."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.perf_counter()

        async def send_with_timing(message: dict) -> None:
            if message["type"] == "http.response.start":
                elapsed_ms = (time.perf_counter() - start) * 1000
                headers = list(message.get("headers", []))
                headers.append(
                    (b"x-process-time-ms", f"{elapsed_ms:.2f}".encode())
                )
                message["headers"] = headers
            await send(message)

        await self.app(scope, receive, send_with_timing)


app.add_middleware(PureASGITimingMiddleware)
```

---

## 3. Background Tasks and Lifespan Events

### 3.1 Background Tasks

```python
from fastapi import BackgroundTasks


def send_email_notification(email: str, message: str) -> None:
    """Runs after the response is sent — do NOT await."""
    mailer.send(to=email, body=message)


@app.post("/orders", status_code=201)
async def create_order(
    order: OrderCreate,
    background_tasks: BackgroundTasks,
) -> OrderOut:
    created = await Order.create(order)
    background_tasks.add_task(send_email_notification, order.email, "Order placed!")
    return created
```

### 3.2 Lifespan Events (Startup/Shutdown)

```python
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Initialize shared resources on startup, clean up on shutdown."""
    # -- Startup --
    app.state.http_client = httpx.AsyncClient(timeout=30)
    app.state.db_pool = await create_pool(dsn=settings.DATABASE_URL)
    yield
    # -- Shutdown --
    await app.state.http_client.aclose()
    await app.state.db_pool.close()


app = FastAPI(lifespan=lifespan)


@app.get("/proxy")
async def proxy(request: Request) -> dict:
    client: httpx.AsyncClient = request.app.state.http_client
    resp = await client.get("https://api.example.com/data")
    return resp.json()
```

---

## 4. WebSocket Patterns

### 4.1 Connection Manager (Rooms + Broadcasting)

```python
from fastapi import WebSocket, WebSocketDisconnect


class ConnectionManager:
    """Manage WebSocket connections with room support."""

    def __init__(self) -> None:
        self.rooms: dict[str, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, room: str) -> None:
        await websocket.accept()
        self.rooms.setdefault(room, []).append(websocket)

    def disconnect(self, websocket: WebSocket, room: str) -> None:
        self.rooms.get(room, []).remove(websocket)
        if not self.rooms.get(room):
            self.rooms.pop(room, None)

    async def broadcast(self, room: str, message: dict) -> None:
        for ws in self.rooms.get(room, []):
            await ws.send_json(message)

    async def send_personal(self, websocket: WebSocket, message: dict) -> None:
        await websocket.send_json(message)


manager = ConnectionManager()


@app.websocket("/ws/{room}")
async def websocket_room(
    websocket: WebSocket,
    room: str,
    token: Annotated[str, Query()],
) -> None:
    user = await verify_ws_token(token)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket, room)
    try:
        while True:
            data = await websocket.receive_json()
            await manager.broadcast(room, {"user": user.name, **data})
    except WebSocketDisconnect:
        manager.disconnect(websocket, room)
        await manager.broadcast(room, {"event": "user_left", "user": user.name})
```

### 4.2 WebSocket with Heartbeat

```python
import asyncio


@app.websocket("/ws/heartbeat")
async def websocket_heartbeat(websocket: WebSocket) -> None:
    await websocket.accept()

    async def send_ping() -> None:
        while True:
            await asyncio.sleep(30)
            await websocket.send_json({"type": "ping"})

    ping_task = asyncio.create_task(send_ping())
    try:
        while True:
            data = await websocket.receive_json()
            if data.get("type") == "pong":
                continue
            await websocket.send_json({"type": "echo", "data": data})
    except WebSocketDisconnect:
        ping_task.cancel()
```

---

## 5. Custom Exception Handlers and Error Responses

```python
from fastapi import Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel


class ErrorResponse(BaseModel):
    """Standardized error envelope."""

    error: str
    detail: str | None = None
    request_id: str | None = None


class DomainError(Exception):
    """Base for all domain-level errors."""

    def __init__(self, message: str, status_code: int = 400) -> None:
        self.message = message
        self.status_code = status_code


class NotFoundError(DomainError):
    def __init__(self, resource: str, resource_id: str) -> None:
        super().__init__(
            message=f"{resource} '{resource_id}' not found",
            status_code=404,
        )


class ConflictError(DomainError):
    def __init__(self, message: str) -> None:
        super().__init__(message=message, status_code=409)


@app.exception_handler(DomainError)
async def domain_error_handler(request: Request, exc: DomainError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=exc.message,
            request_id=getattr(request.state, "request_id", None),
        ).model_dump(),
    )


@app.exception_handler(Exception)
async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    """Catch-all — log and return 500 without leaking internals."""
    import logging

    logging.exception("Unhandled error", exc_info=exc)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(error="Internal server error").model_dump(),
    )
```

---

## 6. File Upload/Download Patterns

### 6.1 Upload with Validation

```python
from fastapi import File, UploadFile

ALLOWED_CONTENT_TYPES = {"image/png", "image/jpeg", "application/pdf"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


@app.post("/upload")
async def upload_file(file: UploadFile = File(...)) -> dict:
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type: {file.content_type}",
        )

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large")

    path = UPLOAD_DIR / file.filename
    path.write_bytes(contents)
    return {"filename": file.filename, "size": len(contents)}
```

### 6.2 Streaming Download

```python
from fastapi.responses import StreamingResponse
from pathlib import Path


@app.get("/download/{filename}")
async def download_file(filename: str) -> StreamingResponse:
    file_path = UPLOAD_DIR / filename
    if not file_path.exists():
        raise NotFoundError("File", filename)

    def iter_file():
        with open(file_path, "rb") as f:
            while chunk := f.read(64 * 1024):
                yield chunk

    return StreamingResponse(
        iter_file(),
        media_type="application/octet-stream",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
```

### 6.3 Multiple File Upload

```python
@app.post("/upload-many")
async def upload_multiple(files: list[UploadFile] = File(...)) -> list[dict]:
    results = []
    for file in files:
        contents = await file.read()
        results.append({"filename": file.filename, "size": len(contents)})
    return results
```

---

## 7. Pagination Patterns

### 7.1 Offset-Based Pagination

```python
from pydantic import BaseModel, Field
from typing import Generic, TypeVar

T = TypeVar("T")


class Page(BaseModel, Generic[T]):
    """Generic paginated response."""

    items: list[T]
    total: int
    offset: int
    limit: int
    has_more: bool


@app.get("/items", response_model=Page[ItemOut])
async def list_items(
    pagination: Annotated[PaginationParams, Depends()],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Page[ItemOut]:
    total = await db.scalar(select(func.count(Item.id)))
    rows = await db.scalars(
        select(Item)
        .offset(pagination.offset)
        .limit(pagination.limit)
        .order_by(Item.created_at.desc())
    )
    items = rows.all()
    return Page(
        items=items,
        total=total,
        offset=pagination.offset,
        limit=pagination.limit,
        has_more=(pagination.offset + pagination.limit) < total,
    )
```

### 7.2 Cursor-Based Pagination

```python
import base64
from datetime import datetime


class CursorPage(BaseModel, Generic[T]):
    items: list[T]
    next_cursor: str | None = None
    has_more: bool


def decode_cursor(cursor: str | None) -> datetime | None:
    if not cursor:
        return None
    return datetime.fromisoformat(base64.b64decode(cursor).decode())


def encode_cursor(dt: datetime) -> str:
    return base64.b64encode(dt.isoformat().encode()).decode()


@app.get("/feed", response_model=CursorPage[PostOut])
async def feed(
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
) -> CursorPage[PostOut]:
    after = decode_cursor(cursor)
    query = select(Post).order_by(Post.created_at.desc()).limit(limit + 1)
    if after:
        query = query.where(Post.created_at < after)

    rows = (await db.scalars(query)).all()
    has_more = len(rows) > limit
    items = rows[:limit]

    return CursorPage(
        items=items,
        has_more=has_more,
        next_cursor=encode_cursor(items[-1].created_at) if has_more else None,
    )
```

---

## 8. Rate Limiting

### 8.1 Simple In-Memory Rate Limiter

```python
import time
from collections import defaultdict

from fastapi import Request


class RateLimiter:
    """Token-bucket rate limiter per client IP."""

    def __init__(self, requests_per_minute: int = 60) -> None:
        self.rpm = requests_per_minute
        self.requests: dict[str, list[float]] = defaultdict(list)

    def is_allowed(self, client_ip: str) -> bool:
        now = time.time()
        window_start = now - 60
        self.requests[client_ip] = [
            t for t in self.requests[client_ip] if t > window_start
        ]
        if len(self.requests[client_ip]) >= self.rpm:
            return False
        self.requests[client_ip].append(now)
        return True


rate_limiter = RateLimiter(requests_per_minute=100)


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host if request.client else "unknown"
    if not rate_limiter.is_allowed(client_ip):
        return JSONResponse(
            status_code=429,
            content={"error": "Too many requests"},
            headers={"Retry-After": "60"},
        )
    return await call_next(request)
```

### 8.2 Redis-Backed Rate Limiter (Production)

```python
import redis.asyncio as redis


class RedisRateLimiter:
    """Sliding window rate limiter backed by Redis."""

    def __init__(self, redis_client: redis.Redis, rpm: int = 60) -> None:
        self.redis = redis_client
        self.rpm = rpm

    async def is_allowed(self, key: str) -> bool:
        pipe = self.redis.pipeline()
        now = time.time()
        window_key = f"rate:{key}"

        pipe.zremrangebyscore(window_key, 0, now - 60)
        pipe.zadd(window_key, {str(now): now})
        pipe.zcard(window_key)
        pipe.expire(window_key, 120)

        results = await pipe.execute()
        return results[2] <= self.rpm
```

---

## 9. Health Check Patterns

```python
from enum import StrEnum

from pydantic import BaseModel


class HealthStatus(StrEnum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"


class ComponentHealth(BaseModel):
    name: str
    status: HealthStatus
    latency_ms: float | None = None
    detail: str | None = None


class HealthResponse(BaseModel):
    status: HealthStatus
    version: str
    components: list[ComponentHealth] = []


@app.get("/healthz", tags=["infra"])
async def liveness() -> dict:
    """Liveness probe — is the process alive?"""
    return {"status": "ok"}


@app.get("/readyz", tags=["infra"])
async def readiness(db: Annotated[AsyncSession, Depends(get_db)]) -> dict:
    """Readiness probe — can the app serve traffic?"""
    try:
        await db.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "not ready"})


@app.get("/health", response_model=HealthResponse, tags=["infra"])
async def deep_health(request: Request) -> HealthResponse:
    """Deep health — check every dependency."""
    components: list[ComponentHealth] = []

    # Database
    start = time.perf_counter()
    try:
        async with request.app.state.db_pool.acquire() as conn:
            await conn.execute("SELECT 1")
        db_ms = (time.perf_counter() - start) * 1000
        components.append(
            ComponentHealth(name="database", status=HealthStatus.HEALTHY, latency_ms=db_ms)
        )
    except Exception as e:
        components.append(
            ComponentHealth(name="database", status=HealthStatus.UNHEALTHY, detail=str(e))
        )

    # Redis
    start = time.perf_counter()
    try:
        await request.app.state.redis.ping()
        redis_ms = (time.perf_counter() - start) * 1000
        components.append(
            ComponentHealth(name="redis", status=HealthStatus.HEALTHY, latency_ms=redis_ms)
        )
    except Exception as e:
        components.append(
            ComponentHealth(name="redis", status=HealthStatus.UNHEALTHY, detail=str(e))
        )

    # Overall status
    statuses = [c.status for c in components]
    if all(s == HealthStatus.HEALTHY for s in statuses):
        overall = HealthStatus.HEALTHY
    elif any(s == HealthStatus.UNHEALTHY for s in statuses):
        overall = HealthStatus.UNHEALTHY
    else:
        overall = HealthStatus.DEGRADED

    return HealthResponse(
        status=overall,
        version=settings.APP_VERSION,
        components=components,
    )
```

---

## 10. Testing Patterns

### 10.1 Sync Tests with TestClient

```python
import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def client() -> TestClient:
    """TestClient fixture with lifespan support."""
    app.dependency_overrides[get_db] = lambda: FakeDB()
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def test_create_item(client: TestClient) -> None:
    response = client.post("/items", json={"name": "Widget", "price": 9.99})
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Widget"
```

### 10.2 Async Tests with httpx

```python
import httpx
import pytest_asyncio
from httpx import ASGITransport


@pytest_asyncio.fixture()
async def async_client() -> httpx.AsyncClient:
    """Async client for testing async dependencies."""
    transport = ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.anyio
async def test_read_items(async_client: httpx.AsyncClient) -> None:
    response = await async_client.get("/items")
    assert response.status_code == 200
```

### 10.3 Dependency Overrides as Fixtures

```python
@pytest.fixture(autouse=True)
def _override_settings() -> None:
    """Override settings for all tests in this module."""

    def settings_override() -> Settings:
        return Settings(database_url="sqlite+aiosqlite:///:memory:")

    app.dependency_overrides[get_settings] = settings_override
    yield
    app.dependency_overrides.pop(get_settings, None)
```

### 10.4 Testing WebSockets

```python
def test_websocket_echo(client: TestClient) -> None:
    with client.websocket_connect("/ws/test-room?token=valid") as ws:
        ws.send_json({"message": "hello"})
        data = ws.receive_json()
        assert data["message"] == "hello"
```

### 10.5 Testing Lifespan Events

```python
def test_lifespan_populates_state() -> None:
    with TestClient(app) as client:
        response = client.get("/proxy")
        assert response.status_code == 200
    # After context exits, shutdown has run — verify cleanup if needed.
```

---

## 11. Security Patterns

### 11.1 OAuth2 + JWT

```python
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, Security
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm, SecurityScopes
from pydantic import BaseModel

ALGORITHM = "HS256"

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/token",
    scopes={"me": "Read own profile", "items": "Read items"},
)


class TokenData(BaseModel):
    sub: str
    scopes: list[str] = []
    exp: datetime


def create_access_token(data: dict, expires_delta: timedelta = timedelta(minutes=30)) -> str:
    payload = {
        **data,
        "exp": datetime.now(timezone.utc) + expires_delta,
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


async def get_current_user(
    security_scopes: SecurityScopes,
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": f'Bearer scope="{security_scopes.scope_str}"'},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        token_scopes = payload.get("scopes", [])
        if username is None:
            raise credentials_exception
    except jwt.InvalidTokenError:
        raise credentials_exception

    user = await db.scalar(select(User).where(User.username == username))
    if user is None:
        raise credentials_exception

    for scope in security_scopes.scopes:
        if scope not in token_scopes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not enough permissions",
            )
    return user


@app.post("/auth/token")
async def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=400, detail="Invalid credentials")
    token = create_access_token({"sub": user.username, "scopes": form_data.scopes})
    return {"access_token": token, "token_type": "bearer"}


@app.get("/users/me")
async def read_own_profile(
    user: Annotated[User, Security(get_current_user, scopes=["me"])],
) -> UserOut:
    return user
```

### 11.2 API Key Authentication

```python
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")


async def verify_api_key(
    api_key: Annotated[str, Depends(api_key_header)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> APIKeyRecord:
    record = await db.scalar(select(APIKeyRecord).where(APIKeyRecord.key == api_key))
    if not record or record.revoked:
        raise HTTPException(status_code=403, detail="Invalid or revoked API key")
    return record


@app.get("/external/data")
async def external_data(
    api_key: Annotated[APIKeyRecord, Depends(verify_api_key)],
) -> dict:
    return {"data": "sensitive", "client": api_key.client_name}
```

### 11.3 Combining Multiple Auth Schemes

```python
from fastapi.security import HTTPBearer

http_bearer = HTTPBearer(auto_error=False)


async def get_user_flexible(
    bearer: Annotated[str | None, Depends(http_bearer)] = None,
    api_key: Annotated[str | None, Depends(APIKeyHeader(name="X-API-Key", auto_error=False))] = None,
) -> User | APIKeyRecord:
    """Accept either Bearer token OR API key."""
    if bearer:
        return await resolve_user_from_jwt(bearer.credentials)
    if api_key:
        return await resolve_client_from_key(api_key)
    raise HTTPException(status_code=401, detail="No credentials provided")
```

---

## 12. Response Model Patterns

### 12.1 Include/Exclude Fields

```python
from pydantic import BaseModel, Field


class UserDB(BaseModel):
    id: int
    username: str
    email: str
    hashed_password: str
    is_admin: bool


class UserPublic(BaseModel):
    id: int
    username: str


class UserPrivate(BaseModel):
    id: int
    username: str
    email: str
    is_admin: bool


@app.get("/users/{user_id}", response_model=UserPublic)
async def read_user(user_id: int) -> UserDB:
    """Returns full UserDB, but FastAPI strips fields not in UserPublic."""
    return await get_user(user_id)


@app.get(
    "/admin/users/{user_id}",
    response_model=UserPrivate,
    response_model_exclude={"is_admin"},
)
async def read_user_admin(user_id: int) -> UserDB:
    return await get_user(user_id)
```

### 12.2 Response Model by Alias

```python
from pydantic import BaseModel, Field


class CamelItem(BaseModel):
    item_name: str = Field(alias="itemName")
    is_available: bool = Field(alias="isAvailable")

    model_config = {"populate_by_name": True}


@app.get("/camel-items/{item_id}", response_model=CamelItem, response_model_by_alias=True)
async def get_camel_item(item_id: int) -> CamelItem:
    """Response JSON uses camelCase keys."""
    return CamelItem(item_name="Widget", is_available=True)
```

### 12.3 Union Responses

```python
from typing import Union


class Cat(BaseModel):
    type: str = "cat"
    purrs: bool


class Dog(BaseModel):
    type: str = "dog"
    barks: bool


@app.get("/pets/{pet_id}", response_model=Union[Cat, Dog])
async def get_pet(pet_id: int) -> Cat | Dog:
    return await pet_repo.get(pet_id)
```

---

## 13. Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|---|---|---|
| `@app.on_event("startup")` | Deprecated since 0.93 | Use `lifespan` context manager |
| `def` endpoint with `await` | Blocks the event loop | Use `async def` for async I/O |
| `async def` with sync I/O | Blocks the event loop | Use `def` (runs in threadpool) or `run_in_executor` |
| Global mutable state without locks | Race conditions | Use `contextvars` or pass via `request.app.state` |
| `BaseHTTPMiddleware` for high-throughput | Memory overhead, streaming issues | Use pure ASGI middleware |
| `response_model=dict` | No validation, no OpenAPI schema | Define a Pydantic model |
| Catching `Exception` in dependencies | Swallows `HTTPException` | Catch specific exceptions, re-raise `HTTPException` |
| `app.dependency_overrides` not cleared | Leaks between tests | Use `try/finally` or `autouse` fixture |
| `UploadFile.read()` for large files | Loads entire file into RAM | Use `file.read(chunk_size)` in a loop |
| Storing secrets in query params | Logged in access logs / browser history | Use headers (`Authorization`, `X-API-Key`) |
| Nested `try/except` in yield deps that swallows errors | Silent failures, 500 with no log | Re-raise after logging; use `finally` for cleanup only |
| Using `jsonable_encoder` to serialize responses | Unnecessary overhead | Let FastAPI handle serialization via `response_model` |
| Missing `status_code` on create endpoints | Returns 200 instead of 201 | Add `status_code=201` to `@app.post` |

---

## 14. Verification Checklist

Before shipping a FastAPI application, verify:

- [ ] **Type hints** on every function signature (params + return)
- [ ] **`Annotated[..., Depends()]`** syntax (not bare `= Depends()`)
- [ ] **`lifespan`** context manager used (not deprecated `on_event`)
- [ ] **Pydantic v2** models with `model_config` (not `class Config`)
- [ ] **`response_model`** set on all public endpoints
- [ ] **`status_code`** explicitly set for POST (201), DELETE (204)
- [ ] **CORS** middleware configured for production origins (not `*`)
- [ ] **Exception handlers** return consistent error envelope
- [ ] **Health endpoints** exist: `/healthz`, `/readyz`, `/health`
- [ ] **Background tasks** do not access request/response objects
- [ ] **Yield dependencies** use `try/finally` for cleanup
- [ ] **Dependency overrides** cleared in test teardown
- [ ] **WebSocket** endpoints handle `WebSocketDisconnect`
- [ ] **File uploads** validate content type and size
- [ ] **Pagination** enforces `limit` upper bound
- [ ] **Rate limiting** in place for public endpoints
- [ ] **Secrets** passed via headers, never query params
- [ ] **Tests** cover happy path, error cases, and auth flows
- [ ] **`async def`** only for truly async I/O; `def` for CPU/sync
- [ ] **No `Any`** in Pydantic models or endpoint signatures
