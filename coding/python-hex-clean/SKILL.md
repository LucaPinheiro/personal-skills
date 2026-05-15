---
name: python-clean-arch
description: MUST USE when working on Python Clean Architecture / Hexagonal projects with FastAPI. Guides implementation of aggregates, value objects, use cases (CQRS), FastAPI routers, and infrastructure following strict hexagonal layering with dependency inversion. Enforces idiomatic Python style from Google Python Style Guide — covering naming, type hints, error handling, testing, and performance patterns.
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: python
  framework: fastapi
  pattern: hexagonal-clean-architecture
---

# Python Hexagonal / Clean Architecture Skill

You are a Python expert building features in a Hexagonal (Ports & Adapters) Clean Architecture with FastAPI. You enforce strict layering, idiomatic Python, DDD patterns, and CQRS — following the **Google Python Style Guide** and modern Python best practices (3.12+).

---

## ARCHITECTURE RULES (NON-NEGOTIABLE)

```
                         ┌──────────────┐
                         │    Domain    │  Entities, Value Objects, Domain Services
                         │   (Core)     │  ZERO external dependencies
                         └──────▲───────┘
                                │
                      ┌─────────┴─────────┐
                      │   Application     │  Use Cases: Commands + Queries
                      │   (Use Cases)     │  Depends only on Domain
                      └─────────▲─────────┘
                                │
               ┌────────────────┴────────────────┐
               │           Adapters              │
               │  Inbound (HTTP, gRPC, CLI)      │
               │  Outbound (DB, Messaging, APIs) │
               └────────────────▲────────────────┘
                                │
                      ┌─────────┴─────────┐
                      │  Infrastructure   │  Config, DI, Server, Wiring
                      └───────────────────┘
```

### Dependency Law

| Package | Can Import | MUST NEVER Import |
|---------|-----------|-------------------|
| **`domain/`** | Standard library, `pydantic` (for value objects) | `application/`, `adapter/`, `infrastructure/`, any DB/HTTP/framework package |
| **`application/`** | `domain/` | `adapter/`, `infrastructure/` |
| **`adapter/`** | `domain/`, `application/` | `infrastructure/` (except config types) |
| **`infrastructure/`** | `domain/`, `application/`, `adapter/` | — |
| **`main.py`** | Everything under `src/` | — |

**VIOLATION = AUTOMATIC FAILURE. If an inner layer needs something from an outer layer, define a port (Protocol/ABC) in the inner layer and implement it in the outer layer.**

### Port / Adapter Contract

- **Ports** are `Protocol` classes or `ABC` subclasses defined by their **consumer** (the inner layer that needs the capability).
- **Adapters** are concrete classes in outer layers that implement port protocols.
- Domain ports live in `domain/{aggregate}/repository.py` or `domain/{aggregate}/service.py`.
- Application ports live in `application/port/`.
- Adapters live in `adapter/outbound/` (driven) or `adapter/inbound/` (driving).
- Never define a protocol and its only implementation in the same module. The consumer owns the interface.

---

## PYTHON STYLE RULES (NON-NEGOTIABLE)

> Source: [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)

### Formatting

- **4 spaces** indentation. Never tabs.
- Maximum **80 characters** per line. Exceptions: long imports, URLs in comments.
- Use implicit line joining inside parentheses/brackets. **Never** use backslash `\` for continuation.
- 2 blank lines between top-level definitions. 1 blank line between methods in a class.
- No trailing whitespace. No semicolons.
- Run `ruff format` and `ruff check` before commit.

### Naming

| Element | Style | Example |
|---------|-------|---------|
| Module/Package | `lower_with_under` | `order_service` |
| Class | `CapWords` | `OrderService` |
| Exception | `CapWords` + `Error` suffix | `OrderNotFoundError` |
| Function/Method | `lower_with_under` | `create_order()` |
| Private function | `_lower_with_under` | `_validate_items()` |
| Instance variable | `lower_with_under` | `total_amount` |
| Protected variable | `_lower_with_under` | `_status` |
| Constant | `CAPS_WITH_UNDER` | `MAX_ITEMS_PER_ORDER` |
| Type alias | `CapWords` | `OrderItems` |

**Naming rules:**
- Name length proportional to scope. Single char for very short loops only.
- Don't include types in names: `users` not `user_list`, `count` not `num_users`.
- Don't repeat module name in symbol: `order.Service` not `order.OrderService`.
- Never use `__double_leading_and_trailing_underscore__` (reserved).
- Never use `l`, `O`, `I` as single-character variable names (ambiguous with 1 and 0).

### Imports

Group in this order, separated by blank lines:

```python
from __future__ import annotations

import os
import sys
from collections.abc import Sequence
from typing import Any

import sqlalchemy as sa
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from src.domain.order.entity import Order
from src.domain.order.repository import OrderRepository
from src.application.order.create import CreateOrderCommand
```

1. `__future__` imports
2. Standard library
3. Third-party packages
4. Project packages

**Rules:**
- **Never** use relative imports — always use full package path.
- **Never** use `from module import *`.
- One import per line (exception: `typing` and `collections.abc` symbols).
- Imports always at the top of the file, after module docstring.

### Type Hints (MANDATORY)

```python
# ALL public APIs must have type annotations
def create_order(
    items: Sequence[OrderItem],
    customer_id: CustomerId,
    *,
    discount: Decimal | None = None,
) -> Order:
    ...

# Variables — annotate when type is not obvious
orders: list[Order] = []
total: Decimal = Decimal("0")

# Never do this:
name: str = None          # WRONG
name: str | None = None   # CORRECT
```

**Rules:**
- All public functions, methods, and class attributes must have type annotations.
- Use `X | None` syntax (Python 3.10+), not `Optional[X]` in new code.
- Prefer abstract types in signatures: `Sequence[T]` not `list[T]`, `Mapping[K, V]` not `dict[K, V]`.
- Use `from __future__ import annotations` for forward references.
- Use `TYPE_CHECKING` guard for import-only-for-typing to avoid circular imports.

### Error Handling

```python
# GOOD: specific exception, clear context
def get_order(order_id: OrderId) -> Order:
    order = self._orders.get(order_id)
    if order is None:
        raise OrderNotFoundError(f"Order {order_id} not found")
    return order

# GOOD: wrap with context
try:
    result = external_api.fetch(url)
except httpx.HTTPError as exc:
    raise ExternalServiceError(f"fetch {url}: {exc}") from exc

# BAD: bare except
try:
    ...
except:  # NEVER
    ...

# BAD: catch-all without re-raise
try:
    ...
except Exception:  # ONLY if re-raising or at isolation boundary
    ...
```

**Rules:**
- Minimize code inside `try` blocks.
- Never use bare `except:` — always specify the exception type.
- Catching `Exception` only at isolation boundaries (top-level handlers) and must re-raise or log.
- Use `raise ... from exc` to preserve exception chains.
- Use `finally` or context managers for cleanup, never `__del__`.
- Don't use `assert` for application logic — only in tests.
- Error messages: lowercase, describe the condition, include relevant values.

### Docstrings (Google Style)

```python
def create_order(
    items: Sequence[OrderItem],
    customer_id: CustomerId,
) -> Order:
    """Create a new order for the given customer.

    Validates items, calculates totals, and registers
    the OrderCreated domain event.

    Args:
        items: Line items for the order. Must not be empty.
        customer_id: The customer placing the order.

    Returns:
        The newly created Order aggregate.

    Raises:
        EmptyOrderError: When items sequence is empty.
        InvalidItemError: When any item has quantity <= 0.
    """
```

**Rules:**
- All public modules, classes, functions, and methods must have docstrings.
- Summary line: one sentence, imperative mood, ends with period.
- Blank line between summary and body.
- `Args:`, `Returns:`, `Raises:` sections with 4-space hanging indent.
- Omit `Returns:` only if function returns `None` and it's obvious.
- Omit `Raises:` for exceptions caused by incorrect API usage.

---

## PROJECT STRUCTURE

```
{project}/
├── src/
│   ├── domain/                         ← CORE: zero external deps (except pydantic)
│   │   ├── __init__.py
│   │   ├── shared/
│   │   │   ├── __init__.py
│   │   │   ├── entity.py              ← Base Entity, AggregateRoot
│   │   │   ├── value_object.py        ← Base ValueObject
│   │   │   ├── event.py               ← DomainEvent, EventBus protocol
│   │   │   ├── repository.py          ← Generic Repository protocol
│   │   │   ├── errors.py              ← Base DomainError
│   │   │   └── types.py               ← Shared type aliases, NewType IDs
│   │   └── {aggregate}/
│   │       ├── __init__.py
│   │       ├── entity.py              ← Aggregate root + child entities
│   │       ├── value_object.py        ← Value objects with validation
│   │       ├── repository.py          ← Port: repository protocol
│   │       ├── service.py             ← Domain service (optional)
│   │       ├── event.py               ← Domain events (optional)
│   │       └── errors.py              ← Aggregate-specific errors
│   │
│   ├── application/                    ← USE CASES: depends only on domain
│   │   ├── __init__.py
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── command.py             ← Command, CommandHandler protocols
│   │   │   ├── query.py               ← Query, QueryHandler protocols
│   │   │   ├── unit_of_work.py        ← UnitOfWork protocol
│   │   │   └── errors.py              ← Application-level errors
│   │   ├── {aggregate}/
│   │   │   ├── __init__.py
│   │   │   ├── create.py              ← CreateXCommand + handler
│   │   │   ├── get.py                 ← GetXQuery + handler
│   │   │   ├── update.py              ← UpdateXCommand + handler
│   │   │   ├── delete.py              ← DeleteXCommand + handler
│   │   │   ├── list.py                ← ListXQuery + handler
│   │   │   └── dto.py                 ← Shared DTOs for this aggregate
│   │   └── port/
│   │       └── {service}.py           ← Application port protocols
│   │
│   ├── adapter/                        ← ADAPTERS: implement ports
│   │   ├── __init__.py
│   │   ├── inbound/
│   │   │   └── http/
│   │   │       ├── __init__.py
│   │   │       ├── router/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── {aggregate}.py ← FastAPI router per aggregate
│   │   │       │   └── health.py      ← Liveness + readiness
│   │   │       ├── schema/
│   │   │       │   └── {aggregate}.py ← Request/Response Pydantic models
│   │   │       ├── middleware/
│   │   │       │   └── {name}.py
│   │   │       └── dependency.py      ← FastAPI Depends factories
│   │   └── outbound/
│   │       ├── persistence/
│   │       │   ├── __init__.py
│   │       │   ├── model/
│   │       │   │   └── {aggregate}.py ← SQLAlchemy ORM models
│   │       │   ├── mapper/
│   │       │   │   └── {aggregate}.py ← Domain ↔ ORM mappers
│   │       │   └── {aggregate}.py     ← Repository implementations
│   │       ├── messaging/
│   │       │   └── {publisher}.py
│   │       └── external/
│   │           └── {client}.py
│   │
│   └── infrastructure/                 ← WIRING: config, DI, server
│       ├── __init__.py
│       ├── config.py                   ← Pydantic Settings
│       ├── database.py                 ← SQLAlchemy engine + session factory
│       ├── container.py                ← Dependency injection wiring
│       ├── server.py                   ← FastAPI app factory
│       └── logging.py                  ← Structured logging setup
│
├── tests/
│   ├── conftest.py                     ← Shared fixtures
│   ├── unit/
│   │   ├── domain/
│   │   │   └── {aggregate}/
│   │   │       ├── test_entity.py
│   │   │       └── test_value_object.py
│   │   └── application/
│   │       └── {aggregate}/
│   │           └── test_create.py
│   ├── integration/
│   │   └── adapter/
│   │       └── persistence/
│   │           └── test_{aggregate}.py
│   └── e2e/
│       └── test_{aggregate}_api.py
│
├── pyproject.toml
├── uv.lock
└── Makefile
```

**Rules:**
- Use `src/` layout. All application code under `src/`.
- One aggregate per directory under `domain/` and `application/`.
- File names: `lower_with_under.py`. Short: `entity.py` not `order_entity.py`.
- Module names match their content. No stuttering: `order.entity.Order` not `order.order_entity.OrderEntity`.
- Every directory has `__init__.py` (can be empty — explicit is better than implicit).

---

## MODE DETECTION (FIRST STEP)

Analyze the user's request to determine what to build:

| User Request Pattern | Mode | Jump To |
|---------------------|------|---------|
| "add entity", "new aggregate", "domain model" | `NEW_AGGREGATE` | Phase 1 |
| "add command", "add query", "new use case" | `NEW_USE_CASE` | Phase 2 |
| "add endpoint", "new route", "new API" | `NEW_ENDPOINT` | Phase 3 |
| "add feature" (end-to-end) | `FULL_FEATURE` | Phase 1 → 2 → 3 → 4 → 5 |
| "add value object", "new VO" | `VALUE_OBJECT` | Phase 1.2 |
| "add domain event" | `DOMAIN_EVENT` | Phase 1.4 |
| "add repository", "add adapter" | `NEW_ADAPTER` | Phase 4 |
| "fix", "update", "change behavior" | `MODIFY` | Assess scope first |

**For FULL_FEATURE**: Execute all phases in order. Create a task list immediately.

---

## PHASE 1: DOMAIN MODEL (`domain/`)

### 1.1 Base Types (`domain/shared/`)

```python
# domain/shared/entity.py
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone

from src.domain.shared.event import DomainEvent


@dataclass
class Entity:
    """Base entity with identity."""

    id: uuid.UUID = field(default_factory=uuid.uuid4)
    created_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc),
    )
    updated_at: datetime | None = field(default=None)


@dataclass
class AggregateRoot(Entity):
    """Base aggregate root with domain event support."""

    _events: list[DomainEvent] = field(
        default_factory=list,
        init=False,
        repr=False,
    )

    def register_event(self, event: DomainEvent) -> None:
        self._events.append(event)

    def collect_events(self) -> list[DomainEvent]:
        events = self._events.copy()
        self._events.clear()
        return events
```

```python
# domain/shared/value_object.py
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ValueObject:
    """Immutable value object base.

    Equality is based on all fields (dataclass default).
    Subclasses must validate in __post_init__.
    """

    def __post_init__(self) -> None:
        self._validate()

    def _validate(self) -> None:
        """Override to add validation. Raise ValueError on failure."""
```

```python
# domain/shared/event.py
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Protocol


@dataclass(frozen=True)
class DomainEvent:
    """Base domain event."""

    event_id: uuid.UUID = field(default_factory=uuid.uuid4)
    occurred_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc),
    )


class EventBus(Protocol):
    """Port for publishing domain events."""

    async def publish(self, events: list[DomainEvent]) -> None: ...
```

```python
# domain/shared/repository.py
from __future__ import annotations

import uuid
from typing import Generic, Protocol, TypeVar

from src.domain.shared.entity import AggregateRoot

T = TypeVar("T", bound=AggregateRoot)


class Repository(Protocol[T]):
    """Generic repository port."""

    async def get_by_id(self, id: uuid.UUID) -> T | None: ...
    async def save(self, entity: T) -> None: ...
    async def delete(self, entity: T) -> None: ...
```

### 1.2 Aggregate Root Entity

```python
# domain/order/entity.py
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal

from src.domain.order.errors import EmptyOrderError, InvalidItemError
from src.domain.order.event import OrderCreatedEvent
from src.domain.order.value_object import (
    CustomerId,
    LineItem,
    Money,
    OrderStatus,
)
from src.domain.shared.entity import AggregateRoot


@dataclass
class Order(AggregateRoot):
    """Order aggregate root."""

    customer_id: CustomerId = field(default_factory=CustomerId)
    items: list[LineItem] = field(default_factory=list)
    status: OrderStatus = field(default=OrderStatus.DRAFT)
    total: Money = field(default_factory=lambda: Money(Decimal("0"), "USD"))

    @classmethod
    def create(
        cls,
        customer_id: CustomerId,
        items: list[LineItem],
    ) -> Order:
        """Create a new order with validation.

        Args:
            customer_id: The customer placing the order.
            items: Line items. Must not be empty.

        Returns:
            A new Order in DRAFT status.

        Raises:
            EmptyOrderError: When items list is empty.
            InvalidItemError: When any item has invalid quantity.
        """
        if not items:
            raise EmptyOrderError("Order must have at least one item")
        for item in items:
            if item.quantity <= 0:
                raise InvalidItemError(
                    f"Item {item.product_id} has invalid "
                    f"quantity: {item.quantity}"
                )

        total = Money.sum(
            item.unit_price * item.quantity for item in items
        )
        order = cls(
            customer_id=customer_id,
            items=items,
            total=total,
        )
        order.register_event(OrderCreatedEvent(order_id=order.id))
        return order

    def confirm(self) -> None:
        """Confirm the order. Transitions from DRAFT to CONFIRMED."""
        if self.status != OrderStatus.DRAFT:
            raise InvalidStatusTransitionError(
                f"Cannot confirm order in {self.status} status"
            )
        self.status = OrderStatus.CONFIRMED
        self.register_event(OrderConfirmedEvent(order_id=self.id))
```

**RULES:**
- Use `@dataclass` for entities. **Never** use mutable defaults directly — always `field(default_factory=...)`.
- Factory classmethods (`create`) for construction with validation and events.
- Mutation methods that enforce invariants. Never expose raw attribute mutation for business rules.
- Register domain events inside mutation methods when side effects are needed.
- All domain errors are specific exceptions, never generic `ValueError` in public API.

### 1.3 Value Objects

```python
# domain/order/value_object.py
from __future__ import annotations

import enum
import uuid
from dataclasses import dataclass
from decimal import Decimal
from typing import NewType

from src.domain.shared.value_object import ValueObject

# Simple ID wrappers — use NewType for zero-overhead typing
CustomerId = NewType("CustomerId", uuid.UUID)
ProductId = NewType("ProductId", uuid.UUID)
OrderId = NewType("OrderId", uuid.UUID)


# Rich value objects — use frozen dataclass
@dataclass(frozen=True)
class Money(ValueObject):
    """Monetary amount with currency."""

    amount: Decimal
    currency: str

    def _validate(self) -> None:
        if self.amount < 0:
            raise ValueError(f"Money amount cannot be negative: {self.amount}")
        if len(self.currency) != 3:
            raise ValueError(f"Invalid currency code: {self.currency}")

    def __mul__(self, quantity: int) -> Money:
        return Money(amount=self.amount * quantity, currency=self.currency)

    @classmethod
    def sum(cls, moneys: Iterable[Money]) -> Money:
        """Sum an iterable of Money values."""
        items = list(moneys)
        if not items:
            return cls(Decimal("0"), "USD")
        currency = items[0].currency
        return cls(
            amount=sum(m.amount for m in items),
            currency=currency,
        )


@dataclass(frozen=True)
class LineItem(ValueObject):
    """Order line item."""

    product_id: ProductId
    quantity: int
    unit_price: Money

    def _validate(self) -> None:
        if self.quantity <= 0:
            raise ValueError(f"Quantity must be positive: {self.quantity}")


class OrderStatus(enum.StrEnum):
    """Order lifecycle status."""

    DRAFT = "draft"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"
```

**DECISION TABLE:**

| Scenario | Use |
|----------|-----|
| Wraps a single primitive (UUID, str, int) | `NewType` for zero overhead |
| Multiple fields with validation | `@dataclass(frozen=True)` + `ValueObject` base |
| Fixed set of named values | `enum.StrEnum` or `enum.IntEnum` |

### 1.4 Domain Events

```python
# domain/order/event.py
from __future__ import annotations

import uuid
from dataclasses import dataclass

from src.domain.shared.event import DomainEvent


@dataclass(frozen=True)
class OrderCreatedEvent(DomainEvent):
    """Raised when a new order is created."""

    order_id: uuid.UUID = uuid.UUID(int=0)


@dataclass(frozen=True)
class OrderConfirmedEvent(DomainEvent):
    """Raised when an order is confirmed."""

    order_id: uuid.UUID = uuid.UUID(int=0)
```

**RULES:**
- Always `@dataclass(frozen=True)` — events are immutable facts.
- Naming: `{Entity}{Action}Event` (e.g., `OrderCreatedEvent`, `PaymentProcessedEvent`).
- Keep payload minimal — just IDs and essential data. Consumers query for details.

### 1.5 Repository Port

```python
# domain/order/repository.py
from __future__ import annotations

import uuid
from collections.abc import Sequence
from typing import Protocol

from src.domain.order.entity import Order


class OrderRepository(Protocol):
    """Port for order persistence."""

    async def get_by_id(self, order_id: uuid.UUID) -> Order | None: ...
    async def save(self, order: Order) -> None: ...
    async def delete(self, order: Order) -> None: ...
    async def list(
        self,
        *,
        offset: int = 0,
        limit: int = 50,
    ) -> Sequence[Order]: ...
    async def count(self) -> int: ...
```

**RULES:**
- Use `Protocol` for ports — structural subtyping, no inheritance needed.
- Async by default (`async def`). Sync only when there's a strong reason.
- Keyword-only args (`*`) for pagination parameters.
- Return `Sequence` (abstract) not `list` (concrete) in protocols.

### 1.6 Domain Errors

```python
# domain/order/errors.py
from __future__ import annotations

from src.domain.shared.errors import DomainError


class OrderError(DomainError):
    """Base error for order aggregate."""


class OrderNotFoundError(OrderError):
    """Raised when an order is not found."""


class EmptyOrderError(OrderError):
    """Raised when attempting to create an order without items."""


class InvalidItemError(OrderError):
    """Raised when a line item is invalid."""


class InvalidStatusTransitionError(OrderError):
    """Raised when an invalid status transition is attempted."""
```

**RULES:**
- All domain errors inherit from `DomainError` base.
- One error per distinct failure condition. No catch-all errors.
- Naming: `{Condition}Error` — descriptive of what went wrong.
- Error messages: lowercase, include relevant values, no trailing punctuation.

---

## PHASE 2: USE CASES (`application/`)

### 2.1 Command / Query Protocols

```python
# application/core/command.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Generic, Protocol, TypeVar

T = TypeVar("T")


@dataclass(frozen=True)
class Command:
    """Base command marker."""


class CommandHandler(Protocol[T]):
    """Handles a command and returns a result."""

    async def handle(self, command: Command) -> T: ...
```

```python
# application/core/query.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Generic, Protocol, TypeVar

T = TypeVar("T")


@dataclass(frozen=True)
class Query:
    """Base query marker."""


class QueryHandler(Protocol[T]):
    """Handles a query and returns a result."""

    async def handle(self, query: Query) -> T: ...
```

### 2.2 Create Command + Handler

```python
# application/order/create.py
from __future__ import annotations

import uuid
from dataclasses import dataclass
from decimal import Decimal

from src.application.core.command import Command
from src.domain.order.entity import Order
from src.domain.order.repository import OrderRepository
from src.domain.order.value_object import (
    CustomerId,
    LineItem,
    Money,
    ProductId,
)
from src.domain.shared.event import EventBus


@dataclass(frozen=True)
class CreateOrderCommand(Command):
    """Command to create a new order."""

    customer_id: uuid.UUID
    items: list[CreateOrderItemInput]


@dataclass(frozen=True)
class CreateOrderItemInput:
    """Input for a single order line item."""

    product_id: uuid.UUID
    quantity: int
    unit_price: Decimal
    currency: str = "USD"


class CreateOrderHandler:
    """Creates a new order from command input.

    Converts raw input to domain value objects, delegates creation
    to the Order aggregate, persists, and publishes domain events.
    """

    def __init__(
        self,
        repository: OrderRepository,
        event_bus: EventBus,
    ) -> None:
        self._repository = repository
        self._event_bus = event_bus

    async def handle(self, command: CreateOrderCommand) -> uuid.UUID:
        """Handle the create order command.

        Args:
            command: The create order command with raw input.

        Returns:
            The UUID of the newly created order.

        Raises:
            EmptyOrderError: When no items are provided.
            InvalidItemError: When any item is invalid.
        """
        items = [
            LineItem(
                product_id=ProductId(item.product_id),
                quantity=item.quantity,
                unit_price=Money(item.unit_price, item.currency),
            )
            for item in command.items
        ]

        order = Order.create(
            customer_id=CustomerId(command.customer_id),
            items=items,
        )

        await self._repository.save(order)
        await self._event_bus.publish(order.collect_events())

        return order.id
```

### 2.3 Get Query + Handler

```python
# application/order/get.py
from __future__ import annotations

import uuid
from dataclasses import dataclass

from src.application.core.query import Query
from src.application.order.dto import OrderDTO
from src.domain.order.errors import OrderNotFoundError
from src.domain.order.repository import OrderRepository


@dataclass(frozen=True)
class GetOrderQuery(Query):
    """Query to get an order by ID."""

    order_id: uuid.UUID


class GetOrderHandler:
    """Retrieves an order by ID."""

    def __init__(self, repository: OrderRepository) -> None:
        self._repository = repository

    async def handle(self, query: GetOrderQuery) -> OrderDTO:
        """Handle the get order query.

        Args:
            query: The query with the order ID.

        Returns:
            The order DTO.

        Raises:
            OrderNotFoundError: When the order does not exist.
        """
        order = await self._repository.get_by_id(query.order_id)
        if order is None:
            raise OrderNotFoundError(
                f"order {query.order_id} not found"
            )
        return OrderDTO.from_entity(order)
```

### 2.4 List Query + Handler

```python
# application/order/list.py
from __future__ import annotations

from dataclasses import dataclass

from src.application.core.query import Query
from src.application.order.dto import OrderDTO, PaginatedResult
from src.domain.order.repository import OrderRepository

DEFAULT_PAGE_SIZE = 50
MAX_PAGE_SIZE = 100


@dataclass(frozen=True)
class ListOrdersQuery(Query):
    """Query to list orders with pagination."""

    page: int = 1
    page_size: int = DEFAULT_PAGE_SIZE


class ListOrdersHandler:
    """Lists orders with pagination."""

    def __init__(self, repository: OrderRepository) -> None:
        self._repository = repository

    async def handle(
        self,
        query: ListOrdersQuery,
    ) -> PaginatedResult[OrderDTO]:
        """Handle the list orders query.

        Args:
            query: Pagination parameters.

        Returns:
            Paginated list of order DTOs.
        """
        page_size = min(query.page_size, MAX_PAGE_SIZE)
        offset = (query.page - 1) * page_size

        orders = await self._repository.list(
            offset=offset,
            limit=page_size,
        )
        total = await self._repository.count()

        return PaginatedResult(
            items=[OrderDTO.from_entity(o) for o in orders],
            total=total,
            page=query.page,
            page_size=page_size,
        )
```

### 2.5 DTO

```python
# application/order/dto.py
from __future__ import annotations

import uuid
from dataclasses import dataclass
from decimal import Decimal
from typing import Generic, TypeVar

from src.domain.order.entity import Order

T = TypeVar("T")


@dataclass(frozen=True)
class OrderDTO:
    """Order data transfer object."""

    id: uuid.UUID
    customer_id: uuid.UUID
    status: str
    total_amount: Decimal
    total_currency: str
    item_count: int

    @classmethod
    def from_entity(cls, order: Order) -> OrderDTO:
        return cls(
            id=order.id,
            customer_id=order.customer_id,
            status=order.status.value,
            total_amount=order.total.amount,
            total_currency=order.total.currency,
            item_count=len(order.items),
        )


@dataclass(frozen=True)
class PaginatedResult(Generic[T]):
    """Generic paginated result."""

    items: list[T]
    total: int
    page: int
    page_size: int
```

**CQRS RULES:**

| Type | Protocol | Returns | Data Access |
|------|----------|---------|-------------|
| Command | `CommandHandler` | ID or None | Repository (read/write) |
| Query | `QueryHandler` | DTO or PaginatedResult | Repository (read-only) or query service |

- Commands MUTATE state — use full repository.
- Queries are READONLY — can bypass repository for performance (raw SQL).
- ALL handlers use domain errors for expected failures. Never return error codes.
- Handler `__init__` declares dependencies. No global state.

---

## PHASE 3: API ENDPOINTS (`adapter/inbound/http/`)

### 3.1 Request / Response Schemas

```python
# adapter/inbound/http/schema/order.py
from __future__ import annotations

import uuid
from decimal import Decimal

from pydantic import BaseModel, Field


class CreateOrderItemRequest(BaseModel):
    """Request schema for a single order item."""

    product_id: uuid.UUID
    quantity: int = Field(gt=0)
    unit_price: Decimal = Field(gt=0)
    currency: str = Field(default="USD", min_length=3, max_length=3)


class CreateOrderRequest(BaseModel):
    """Request schema for creating an order."""

    customer_id: uuid.UUID
    items: list[CreateOrderItemRequest] = Field(min_length=1)


class OrderResponse(BaseModel):
    """Response schema for an order."""

    id: uuid.UUID
    customer_id: uuid.UUID
    status: str
    total_amount: Decimal
    total_currency: str
    item_count: int


class PaginatedOrderResponse(BaseModel):
    """Paginated response for order listing."""

    items: list[OrderResponse]
    total: int
    page: int
    page_size: int
```

### 3.2 Router

```python
# adapter/inbound/http/router/order.py
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status

from src.adapter.inbound.http.dependency import get_create_order_handler
from src.adapter.inbound.http.schema.order import (
    CreateOrderRequest,
    OrderResponse,
    PaginatedOrderResponse,
)
from src.application.order.create import CreateOrderCommand, CreateOrderItemInput
from src.application.order.get import GetOrderQuery
from src.application.order.list import ListOrdersQuery
from src.domain.order.errors import OrderNotFoundError

router = APIRouter(prefix="/orders", tags=["Orders"])


@router.post(
    "",
    response_model=OrderResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new order",
)
async def create_order(
    request: CreateOrderRequest,
    handler=Depends(get_create_order_handler),
) -> OrderResponse:
    """Create a new order with the given items."""
    command = CreateOrderCommand(
        customer_id=request.customer_id,
        items=[
            CreateOrderItemInput(
                product_id=item.product_id,
                quantity=item.quantity,
                unit_price=item.unit_price,
                currency=item.currency,
            )
            for item in request.items
        ],
    )
    order_id = await handler.handle(command)

    # Fetch the created order to return full response
    query_handler = ...  # injected via Depends
    result = await query_handler.handle(GetOrderQuery(order_id=order_id))
    return OrderResponse(**result.__dict__)


@router.get(
    "/{order_id}",
    response_model=OrderResponse,
    summary="Get an order by ID",
)
async def get_order(
    order_id: uuid.UUID,
    handler=Depends(get_get_order_handler),
) -> OrderResponse:
    """Retrieve a single order by its ID."""
    try:
        result = await handler.handle(GetOrderQuery(order_id=order_id))
    except OrderNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order {order_id} not found",
        )
    return OrderResponse(**result.__dict__)


@router.get(
    "",
    response_model=PaginatedOrderResponse,
    summary="List orders",
)
async def list_orders(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=100),
    handler=Depends(get_list_orders_handler),
) -> PaginatedOrderResponse:
    """List orders with pagination."""
    result = await handler.handle(
        ListOrdersQuery(page=page, page_size=page_size),
    )
    return PaginatedOrderResponse(
        items=[OrderResponse(**o.__dict__) for o in result.items],
        total=result.total,
        page=result.page,
        page_size=result.page_size,
    )
```

### ENDPOINT RULES

- **One router per aggregate** — `order.py`, `customer.py`, etc.
- **Pydantic schemas at the boundary** — request/response models in `schema/`.
- **Dependency injection via `Depends`** — handlers injected, never constructed inline.
- **Domain error → HTTP error mapping** at the endpoint level. Handlers never raise HTTP exceptions.
- **Value object conversion at boundary** — convert raw request data to domain types in the command, not in the handler.
- **All list endpoints paginated** — enforce max page size.

---

## PHASE 4: INFRASTRUCTURE

### 4.1 SQLAlchemy ORM Model

```python
# adapter/outbound/persistence/model/order.py
from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

import sqlalchemy as sa
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.infrastructure.database import Base


class OrderModel(Base):
    """SQLAlchemy model for orders."""

    __tablename__ = "orders"

    id: Mapped[uuid.UUID] = mapped_column(
        sa.Uuid, primary_key=True, default=uuid.uuid4,
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(sa.Uuid, nullable=False)
    status: Mapped[str] = mapped_column(
        sa.String(20), nullable=False, default="draft",
    )
    total_amount: Mapped[Decimal] = mapped_column(
        sa.Numeric(12, 2), nullable=False,
    )
    total_currency: Mapped[str] = mapped_column(
        sa.String(3), nullable=False, default="USD",
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.DateTime(timezone=True),
        server_default=sa.func.now(),
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        sa.DateTime(timezone=True), onupdate=sa.func.now(),
    )
    items: Mapped[list[OrderItemModel]] = relationship(
        back_populates="order", cascade="all, delete-orphan",
    )
```

### 4.2 Repository Implementation

```python
# adapter/outbound/persistence/order.py
from __future__ import annotations

import uuid
from collections.abc import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from src.adapter.outbound.persistence.mapper.order import OrderMapper
from src.adapter.outbound.persistence.model.order import OrderModel
from src.domain.order.entity import Order


class SqlAlchemyOrderRepository:
    """SQLAlchemy implementation of OrderRepository port."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, order_id: uuid.UUID) -> Order | None:
        """Get an order by ID."""
        stmt = select(OrderModel).where(OrderModel.id == order_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            return None
        return OrderMapper.to_entity(model)

    async def save(self, order: Order) -> None:
        """Save an order (insert or update)."""
        model = OrderMapper.to_model(order)
        self._session.add(model)
        await self._session.flush()

    async def delete(self, order: Order) -> None:
        """Delete an order."""
        stmt = select(OrderModel).where(OrderModel.id == order.id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is not None:
            await self._session.delete(model)

    async def list(
        self,
        *,
        offset: int = 0,
        limit: int = 50,
    ) -> Sequence[Order]:
        """List orders with pagination."""
        stmt = (
            select(OrderModel)
            .order_by(OrderModel.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return [
            OrderMapper.to_entity(model)
            for model in result.scalars().all()
        ]

    async def count(self) -> int:
        """Count total orders."""
        stmt = select(func.count()).select_from(OrderModel)
        result = await self._session.execute(stmt)
        return result.scalar_one()
```

### 4.3 Configuration

```python
# infrastructure/config.py
from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment."""

    model_config = {"env_prefix": "APP_", "env_file": ".env"}

    # Database
    database_url: str = "postgresql+asyncpg://localhost/myapp"
    database_pool_size: int = 10
    database_max_overflow: int = 5

    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False

    # Logging
    log_level: str = "INFO"
    log_format: str = "json"
```

### 4.4 Database Setup

```python
# infrastructure/database.py
from __future__ import annotations

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from src.infrastructure.config import Settings


class Base(DeclarativeBase):
    """SQLAlchemy declarative base."""


def create_engine(settings: Settings) -> AsyncEngine:
    """Create async SQLAlchemy engine."""
    return create_async_engine(
        settings.database_url,
        pool_size=settings.database_pool_size,
        max_overflow=settings.database_max_overflow,
        echo=settings.debug,
    )


def create_session_factory(
    engine: AsyncEngine,
) -> async_sessionmaker[AsyncSession]:
    """Create async session factory."""
    return async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
```

### 4.5 Dependency Injection

```python
# infrastructure/container.py
from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession

from src.adapter.outbound.persistence.order import SqlAlchemyOrderRepository
from src.application.order.create import CreateOrderHandler
from src.application.order.get import GetOrderHandler
from src.application.order.list import ListOrdersHandler
from src.infrastructure.config import Settings
from src.infrastructure.database import create_engine, create_session_factory

settings = Settings()
engine = create_engine(settings)
session_factory = create_session_factory(engine)


async def get_session() -> AsyncIterator[AsyncSession]:
    """Yield a database session per request."""
    async with session_factory() as session:
        yield session
        await session.commit()


def get_order_repository(session: AsyncSession) -> SqlAlchemyOrderRepository:
    """Create order repository."""
    return SqlAlchemyOrderRepository(session)


def get_create_order_handler(
    session: AsyncSession,
) -> CreateOrderHandler:
    """Create the CreateOrderHandler with dependencies."""
    return CreateOrderHandler(
        repository=get_order_repository(session),
        event_bus=InMemoryEventBus(),
    )
```

### 4.6 Alembic Migration

```bash
# Initialize (once)
alembic init alembic

# Generate migration
alembic revision --autogenerate -m "add_orders_table"

# Apply
alembic upgrade head
```

---

## PHASE 5: VERIFICATION CHECKLIST

### After Every Feature Implementation

```
VERIFICATION CHECKLIST
======================

ARCHITECTURE:
  [ ] Domain has NO imports from application/, adapter/, infrastructure/
  [ ] Application has NO imports from adapter/ or infrastructure/
  [ ] Ports defined as Protocol in inner layer, implemented in outer layer
  [ ] DI wiring in infrastructure/container.py

DOMAIN MODEL:
  [ ] Entities use @dataclass, never mutable defaults
  [ ] Value objects use @dataclass(frozen=True)
  [ ] Mutations through methods, not direct attribute assignment
  [ ] Domain events registered in mutation methods
  [ ] Domain errors are specific exceptions (not ValueError/TypeError)
  [ ] Factory classmethods for complex construction

USE CASES:
  [ ] Commands use repository (read/write)
  [ ] Queries use repository (read-only) or query service
  [ ] All handlers declare dependencies in __init__
  [ ] No framework imports in use cases

ENDPOINTS:
  [ ] Request/Response schemas are Pydantic models in schema/
  [ ] Domain errors mapped to HTTP errors in router
  [ ] All list endpoints paginated with max page size
  [ ] Handlers injected via Depends, never constructed inline

INFRASTRUCTURE:
  [ ] ORM models separate from domain entities
  [ ] Mapper converts between domain entities and ORM models
  [ ] AsyncSession per request via dependency injection
  [ ] Alembic migration generated and applied

PYTHON STYLE (Google):
  [ ] 4-space indentation, 80-char line limit
  [ ] Type hints on all public APIs
  [ ] Google-style docstrings on all public APIs
  [ ] Imports grouped: future → stdlib → third-party → local
  [ ] No relative imports
  [ ] snake_case functions/variables, CapWords classes
  [ ] CAPS_WITH_UNDER constants
  [ ] No bare except, no mutable defaults, no global state

TESTING:
  [ ] Unit tests for domain entities and value objects
  [ ] Unit tests for use case handlers (mocked ports)
  [ ] Integration tests for repository implementations
  [ ] ruff check passes with zero warnings
  [ ] mypy --strict passes (or pyright)
  [ ] pytest passes with target coverage

PERFORMANCE:
  [ ] Async throughout (async def, await)
  [ ] No N+1 queries — use eager loading or projections
  [ ] All list queries paginated (offset/limit, bounded)
  [ ] Connection pooling configured
  [ ] No string accumulation with += in loops
```

Run `ruff check . && mypy src/ && pytest` after changes.

---

## FULL FEATURE CHECKLIST (End-to-End)

When adding a complete new feature/aggregate, create these files IN ORDER:

```
STEP  LAYER           FILE                                              DEPENDS ON
────  ──────────────  ──────────────────────────────────────────────    ──────────
 1    Domain/Shared   shared/errors.py (if not exists)                  —
 2    Domain          {aggregate}/errors.py                             Step 1
 3    Domain          {aggregate}/value_object.py                       —
 4    Domain          {aggregate}/event.py                              —
 5    Domain          {aggregate}/entity.py                             Steps 2-4
 6    Domain          {aggregate}/repository.py (port)                  Step 5
 7    App/Core        core/command.py, core/query.py (if not exists)    —
 8    Application     {aggregate}/dto.py                                Step 5
 9    Application     {aggregate}/create.py                             Steps 5-6, 8
10    Application     {aggregate}/get.py                                Steps 6, 8
11    Application     {aggregate}/list.py                               Steps 6, 8
12    Application     {aggregate}/update.py                             Steps 5-6
13    Application     {aggregate}/delete.py                             Step 6
14    Adapter/Schema  inbound/http/schema/{aggregate}.py                Step 8
15    Adapter/Router  inbound/http/router/{aggregate}.py                Steps 9-13, 14
16    Adapter/Model   outbound/persistence/model/{aggregate}.py         —
17    Adapter/Mapper  outbound/persistence/mapper/{aggregate}.py        Steps 5, 16
18    Adapter/Repo    outbound/persistence/{aggregate}.py               Steps 6, 16, 17
19    Infra           container.py (add DI wiring)                      Steps 9-13, 18
20    Infra           database.py (add model import if needed)          Step 16
21    Migration       alembic revision --autogenerate                   Steps 16, 20
22    Tests           unit/domain/{aggregate}/test_entity.py            Step 5
23    Tests           unit/domain/{aggregate}/test_value_object.py      Step 3
24    Tests           unit/application/{aggregate}/test_create.py       Step 9
25    Tests           integration/adapter/test_{aggregate}.py           Step 18
26    ALL             ruff + mypy + pytest                              All above
```

---

## ANTI-PATTERNS (AUTOMATIC FAILURE)

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Mutable default arguments | Shared across calls, causes subtle bugs | Use `None` default, create inside function |
| `from module import *` | Pollutes namespace, hides dependencies | Import specific names |
| Relative imports | Fragile, breaks on refactoring | Always use absolute imports |
| Bare `except:` | Catches SystemExit, KeyboardInterrupt | Catch specific exceptions |
| `assert` in production code | Disabled with `-O` flag | Use `if condition: raise` |
| Domain entities as Pydantic models | Couples domain to serialization framework | Separate entity (dataclass) from schema (Pydantic) |
| Repository in router | Router should not know data access | Inject use case handler via Depends |
| Framework types in domain | Violates dependency rule | Domain uses stdlib + own types only |
| Sync I/O in async handlers | Blocks the event loop | Use async drivers (asyncpg, httpx) |
| String accumulation with `+=` | Quadratic time complexity | Use `"".join(items)` or `io.StringIO` |
| `staticmethod` without reason | Usually should be a module-level function | Use plain function |
| Global mutable state | Untestable, race conditions | Inject dependencies explicitly |
| Catching Exception without re-raise | Swallows all errors silently | Catch specific errors or re-raise |
| No type hints on public API | Loses static analysis, IDE support | Annotate all public functions |
| `type: ignore` without code | Silences all type errors on line | Use specific code: `type: ignore[arg-type]` |

---

## NAMING CONVENTIONS

| Concept | Convention | Example |
|---------|-----------|---------|
| Aggregate directory | `lower_with_under` | `order/` |
| Entity class | `CapWords` | `Order` |
| Value Object | `CapWords` | `Money`, `LineItem` |
| NewType ID | `CapWords` + `Id` | `OrderId`, `CustomerId` |
| Enum | `CapWords` + `StrEnum` | `OrderStatus` |
| Domain Event | `{Entity}{Action}Event` | `OrderCreatedEvent` |
| Domain Error | `{Condition}Error` | `OrderNotFoundError` |
| Repository port | `{Entity}Repository` | `OrderRepository` |
| Command | `{Action}{Entity}Command` | `CreateOrderCommand` |
| Command Handler | `{Action}{Entity}Handler` | `CreateOrderHandler` |
| Query | `{Action}{Entity}Query` | `GetOrderQuery` |
| Query Handler | `{Action}{Entity}Handler` | `GetOrderHandler` |
| DTO | `{Entity}DTO` | `OrderDTO` |
| Request schema | `{Action}{Entity}Request` | `CreateOrderRequest` |
| Response schema | `{Entity}Response` | `OrderResponse` |
| Router | `{aggregate}.py` | `order.py` |
| ORM model | `{Entity}Model` | `OrderModel` |
| Mapper | `{Entity}Mapper` | `OrderMapper` |
| Repository impl | `SqlAlchemy{Entity}Repository` | `SqlAlchemyOrderRepository` |
| Config | `Settings` | `Settings` |
| Test file | `test_{module}.py` | `test_entity.py` |

---

## TECHNOLOGY REFERENCE

| Library | Purpose | Used In |
|---------|---------|---------|
| `pydantic` | Request/Response validation, Settings | Adapter (schemas), Infrastructure (config) |
| `pydantic-settings` | Environment-based configuration | Infrastructure |
| `fastapi` | HTTP framework, dependency injection | Adapter (inbound) |
| `uvicorn` | ASGI server | Infrastructure |
| `sqlalchemy[asyncio]` | Async ORM, query builder | Adapter (outbound) |
| `asyncpg` | Async PostgreSQL driver | Infrastructure |
| `alembic` | Database migrations | Infrastructure |
| `structlog` | Structured logging | Infrastructure |
| `ruff` | Linting + formatting (replaces black, isort, flake8) | Tooling |
| `mypy` or `pyright` | Static type checking | Tooling |
| `pytest` | Testing framework | Tests |
| `pytest-asyncio` | Async test support | Tests |
| `httpx` | Async HTTP client (tests + external APIs) | Tests, Adapter (outbound) |

---

## TOOLING CONFIGURATION

### pyproject.toml (key sections)

```toml
[tool.ruff]
target-version = "py312"
line-length = 80

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "SIM",  # flake8-simplicity
    "TCH",  # flake8-type-checking
    "RUF",  # ruff-specific
]

[tool.ruff.lint.isort]
known-first-party = ["src"]

[tool.mypy]
strict = true
plugins = ["pydantic.mypy"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```
