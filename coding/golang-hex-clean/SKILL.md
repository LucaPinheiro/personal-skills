---
name: golang-hex-clean
description: MUST USE when working on Go Hexagonal/Clean Architecture projects. Guides implementation of aggregates, value objects, use cases (CQRS), HTTP/gRPC adapters, and infrastructure following strict hexagonal layering with dependency inversion. Enforces idiomatic Go style from Google, Uber, and Effective Go — covering naming, error handling, interfaces, concurrency, and testing patterns.
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: golang
  pattern: hexagonal-clean-architecture
---

# Go Hexagonal / Clean Architecture Skill

You are a Go expert building features in a Hexagonal (Ports & Adapters) Clean Architecture. You enforce strict layering, idiomatic Go, and DDD patterns — synthesizing rules from **Google Go Style Guide**, **Effective Go**, and **Uber Go Style Guide**.

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
| **`internal/domain/`** | Standard library only | `application/`, `adapter/`, `infrastructure/`, any DB/HTTP/framework package |
| **`internal/application/`** | `domain/` | `adapter/`, `infrastructure/` |
| **`internal/adapter/`** | `domain/`, `application/` | `infrastructure/` (except config types) |
| **`internal/infrastructure/`** | `domain/`, `application/`, `adapter/` | — |
| **`cmd/`** | Everything under `internal/` | — |

**VIOLATION = AUTOMATIC FAILURE. If an inner layer needs something from an outer layer, define a port (interface) in the inner layer and implement it in the outer layer.**

### Port / Adapter Contract

- **Ports** are Go interfaces defined by their **consumer** (the inner layer that needs the capability).
- **Adapters** are concrete structs in outer layers that implement port interfaces.
- Domain ports live in `internal/domain/{aggregate}/repository.go` or `internal/domain/{aggregate}/service.go`.
- Application ports live in `internal/application/port/`.
- Adapters live in `internal/adapter/outbound/` (driven) or `internal/adapter/inbound/` (driving).
- Never define an interface and its only implementation in the same package. The consumer owns the interface.

---

## GO STYLE RULES (NON-NEGOTIABLE)

These rules are synthesized from Google Go Style Guide, Effective Go, and Uber Go Style Guide. They apply to ALL code in the project.

### Formatting

- ALL Go source files MUST conform to `gofmt` output. No exceptions.
- Indentation: tabs. Alignment: spaces (handled by `gofmt`).
- No fixed line length limit. Soft limit of 99 characters (Uber). Prefer refactoring over splitting.
- Never split before indentation changes or to break URLs/long strings.
- Run `goimports` on save. Run `go vet` and `staticcheck` before commit.

### Naming

**General:**
- `MixedCaps` or `mixedCaps`. NEVER `snake_case` (exception: test function names in `*_test.go`).
- Constants use `MixedCaps`: `MaxRetries`, not `MAX_RETRIES` or `kMaxRetries`.
- Name length proportional to scope: single char for 1-7 line scope, descriptive for 25+ lines.
- Omit types from names: `users` not `userSlice`, `count` not `numUsers`.
- Don't repeat package name in symbol: `widget.New` not `widget.NewWidget`.

**Packages:**
- Lowercase only. No underscores, no mixedCaps. Concise single words.
- Never: `util`, `utility`, `common`, `helper`, `model`, `base`, `shared`, `lib`.
- Not plural: `net/url` not `net/urls`.

**Receivers:**
- 1-2 letter abbreviation of the type. Consistent for all methods.
- NEVER `this` or `self`.

**Initialisms:**
- Consistent case: `URL` or `url`, never `Url`. `ID` not `Id`. `HTTP` not `Http`.

**Getters/Setters:**
- No `Get` prefix. Field `owner` → getter `Owner()`, setter `SetOwner()`.
- For complex/remote operations use `Compute`, `Fetch`, or `Load` instead.

**Interfaces:**
- One-method interfaces: method name + `-er` suffix (`Reader`, `Writer`, `Stringer`).
- Keep interfaces small. Consumer defines them with only the methods it uses.
- Accept interfaces, return concrete types (except `error`).

**Error Variables and Types:**
- Exported sentinels: `ErrNotFound`, `ErrAlreadyExists`.
- Unexported sentinels: `errNotFound`, `errTimeout`.
- Custom error types: `NotFoundError`, `ValidationError` (suffix `Error`).

**Unexported Globals:**
- Prefix with `_`: `_defaultTimeout`, `_maxRetries`.
- Exception: error sentinels use `err` prefix without underscore.

### Imports

Group in this order, separated by blank lines:

```go
import (
	"context"
	"fmt"

	"{module}/internal/domain/order"
	"{module}/internal/application/port"

	"github.com/google/uuid"
	"go.uber.org/zap"
)
```

1. Standard library
2. Project packages
3. Third-party packages

- Avoid import renaming unless there is a collision.
- Never use `import .` (dot imports).
- Side-effect imports (`import _`) only in `main` or test packages.

### Error Handling

**Returning errors:**
- `error` is always the last return value.
- Return `nil` for success.
- Exported functions return `error` interface, never concrete error types.

**Error strings:**
- Lowercase, no ending punctuation: `fmt.Errorf("open file: %w", err)`.
- Start with context (operation or package): `"parse config: %w"`.
- Keep context succinct: `"new store: %w"` NOT `"failed to create new store: %w"`.

**Error flow:**
```go
// GOOD: handle error first, normal code at base indentation
result, err := doSomething()
if err != nil {
    return fmt.Errorf("do something: %w", err)
}
// use result

// BAD: unnecessary else
result, err := doSomething()
if err != nil {
    return err
} else {
    // use result — indented unnecessarily
}
```

**Wrapping — `%w` vs `%v`:**
- `%w` (default): preserves error chain for `errors.Is`/`errors.As`. Use within your application.
- `%v`: breaks chain. Use at system boundaries (RPC, IPC) or when wrapping would leak implementation.
- Place `%w` at end: `fmt.Errorf("get user %q: %w", id, err)`.
- Sentinel at beginning: `fmt.Errorf("%w: parse input: %v", ErrInvalid, err)`.

**Handle once:**
- Do NOT log and return the same error. Choose one.
- If returning: wrap with context.
- If handling: log and degrade gracefully.

**Type assertions:**
- ALWAYS use comma-ok form: `t, ok := i.(string)`. Never single-return form (panics).

### Interfaces

- Do NOT define interfaces until a real need exists (at least two implementations or a test double).
- Consumer defines the interface, not the producer.
- Keep interfaces small — 1-3 methods preferred.
- Do NOT wrap clients in manual interfaces just for abstraction.
- Verify compliance at compile time:
```go
var _ Repository = (*PostgresRepository)(nil)
```

### Concurrency

- **Share by communicating.** Don't communicate by sharing memory.
- Every goroutine MUST have a predictable stop time or a stop signal.
- Never fire-and-forget goroutines. Use `sync.WaitGroup`, `context.Context`, or done channels.
- Channel size: 0 (unbuffered) or 1. Any other size needs justification.
- Prefer synchronous functions over async. Let the caller decide to `go`.
- Zero-value `sync.Mutex` is valid — no pointer needed. Keep as unexported field (`mu sync.Mutex`), never embed.
- No goroutines in `init()`.
- Copy slices and maps at boundaries to prevent external mutation.

### Testing

- **Table-driven tests** with subtests (`t.Run`):
```go
tests := []struct {
    name string
    give string
    want int
}{
    {name: "empty", give: "", want: 0},
    {name: "single", give: "a", want: 1},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got := Len(tt.give)
        assert.Equal(t, tt.want, got)
    })
}
```
- Use `testify/assert` for assertions that should continue on failure. Use `testify/require` when subsequent checks would be meaningless (stops the test immediately).
- Use `go.uber.org/mock/gomock` for generating and using interface mocks. Generate with `mockgen`, set expectations with `EXPECT()`.
- Test helpers call `t.Helper()` and use `require` for setup failures.
- Never call `require` from separate goroutines — use `assert` instead.
- Use `package foo_test` for black-box/integration tests. Use `package foo` when testing unexported internals.
- **Minimum 95% code coverage.** Run `go test -coverprofile=coverage.out ./...` and verify with `go tool cover -func=coverage.out`.

### Performance (Hot Paths)

- `strconv.Itoa` over `fmt.Sprint` for int-to-string (~2x faster).
- Convert string to `[]byte` once outside loops.
- Preallocate slices: `make([]T, 0, knownSize)`.
- Preallocate maps: `make(map[K]V, knownSize)`.
- Use `strings.Builder` for piecemeal string construction.

### Things You Must NOT Do

- **Don't panic** in production code. Return errors. Use `log.Fatal` only in `main()`.
- **Don't use `init()`** for side effects, I/O, global state, or goroutines. Acceptable only for: precomputed constants, `sql.Register`-style plugin hooks.
- **Don't use mutable globals.** Inject dependencies explicitly. No package-level vars controlling behavior.
- **Don't embed mutexes.** Keep as unexported named field: `mu sync.Mutex`.
- **Don't shadow builtins.** Never redefine `error`, `string`, `len`, `cap`, `new`, `make`, etc.
- **Don't use `math/rand` for security.** Use `crypto/rand` for keys/tokens.
- **Don't use naked `bool` parameters.** Use named types or comment: `printInfo("foo", true /* isLocal */)`.
- **Don't distinguish nil from empty slice** in APIs. Check emptiness with `len(s) == 0`.

---

## PROJECT STRUCTURE

```
{project}/
├── cmd/
│   └── {app}/
│       └── main.go                    ← Entrypoint: run() pattern, single exit
│
├── internal/
│   ├── domain/                        ← CORE: zero external dependencies
│   │   ├── {aggregate}/
│   │   │   ├── entity.go             ← Aggregate root + child entities
│   │   │   ├── valueobject.go        ← Value objects with validation
│   │   │   ├── repository.go         ← Port: repository interface
│   │   │   ├── service.go            ← Domain service (optional)
│   │   │   └── event.go              ← Domain events (optional)
│   │   └── shared/
│   │       ├── valueobject.go        ← Cross-aggregate value objects (Money, Email)
│   │       ├── event.go              ← DomainEvent + EventBus + EventHandler interfaces
│   │       ├── transaction.go        ← Transaction + TransactionFactory interfaces
│   │       └── provider.go           ← TimeProvider, UUIDProvider (testability)
│   │
│   ├── application/                   ← USE CASES: depends only on domain
│   │   ├── core/
│   │   │   ├── handler.go            ← Generic CommandHandler[C,R] / QueryHandler[Q,R]
│   │   │   ├── decorator.go          ← Logging, metrics, tracing decorators
│   │   │   ├── transactional.go      ← ExecuteInTransaction helper
│   │   │   └── apperror.go           ← Structured AppError type system
│   │   ├── factory.go                ← Application struct (Commands + Queries aggregation)
│   │   ├── {aggregate}/
│   │   │   ├── create.go             ← CreateXCommand + handler (one use case per file)
│   │   │   ├── get.go                ← GetXQuery + handler
│   │   │   ├── update.go             ← UpdateXCommand + handler
│   │   │   ├── delete.go             ← DeleteXCommand + handler
│   │   │   ├── list.go               ← ListXQuery + handler
│   │   │   └── dto.go                ← Shared DTOs for this aggregate
│   │   └── port/
│   │       └── {service}.go          ← Application port interfaces (mailer, storage, etc.)
│   │
│   ├── adapter/                       ← ADAPTERS: implement ports
│   │   ├── inbound/
│   │   │   ├── http/
│   │   │   │   ├── handler/
│   │   │   │   │   ├── {aggregate}.go  ← HTTP handlers per aggregate
│   │   │   │   │   └── health.go       ← Liveness + readiness probes
│   │   │   │   ├── middleware/
│   │   │   │   │   └── {name}.go       ← HTTP middleware
│   │   │   │   ├── converter/
│   │   │   │   │   └── {aggregate}.go  ← Request → Command/Query converters
│   │   │   │   ├── request/
│   │   │   │   │   └── {aggregate}.go  ← Request types + validation
│   │   │   │   ├── response/
│   │   │   │   │   └── {aggregate}.go  ← Response types
│   │   │   │   └── router.go          ← Route registration
│   │   │   └── grpc/
│   │   │       └── {service}.go       ← gRPC server implementations
│   │   └── outbound/
│   │       ├── persistence/
│   │       │   └── {aggregate}.go     ← DB repository implementations
│   │       ├── messaging/
│   │       │   └── {publisher}.go     ← Event publisher implementations
│   │       └── external/
│   │           └── {client}.go        ← External API client implementations
│   │
│   └── infrastructure/                ← WIRING: config, DI, server setup
│       ├── config/
│       │   └── config.go              ← Viper-based configuration loading
│       ├── logger/
│       │   └── logger.go              ← Zap logger factory
│       ├── telemetry/
│       │   └── otel.go                ← OpenTelemetry SDK bootstrap + shutdown
│       ├── database/
│       │   └── postgres.go            ← DB connection setup
│       ├── eventbus/
│       │   ├── inmemory.go            ← Synchronous in-process event bus
│       │   └── async.go              ← Async event bus with worker pool
│       ├── server/
│       │   └── http.go                ← HTTP/Fiber server with graceful shutdown
│       ├── archtest/
│       │   └── arch_test.go           ← Dependency rule enforcement tests
│       └── di/
│           └── container.go           ← Dependency injection (manual or Wire)
│
├── pkg/                               ← Public shared libraries (use sparingly)
│   └── {lib}/
│       └── {lib}.go
│
├── go.mod
├── go.sum
└── Makefile
```

**Rules:**
- Use `internal/` for ALL application code. Nothing leaks.
- `pkg/` only for truly reusable libraries shared across multiple projects. Default: don't create it.
- One aggregate per directory under `domain/` and `application/`.
- File names: lowercase, no underscores (except `_test.go`). Short: `entity.go` not `order_entity.go`.
- Package names match directory names. No stuttering: `order.Entity` not `order.OrderEntity`.

---

## MODE DETECTION (FIRST STEP)

Analyze the user's request to determine what to build:

| User Request Pattern | Mode | Jump To |
|---------------------|------|---------|
| "add entity", "new aggregate", "domain model" | `NEW_AGGREGATE` | Phase 1 |
| "add command", "add query", "new use case" | `NEW_USE_CASE` | Phase 2 |
| "add handler", "new endpoint", "new route", "new API" | `NEW_ENDPOINT` | Phase 3 |
| "add feature" (end-to-end) | `FULL_FEATURE` | Phase 1 → 2 → 3 → 4 → 5 |
| "add value object", "new VO" | `VALUE_OBJECT` | Phase 1.2 |
| "add domain event" | `DOMAIN_EVENT` | Phase 1.4 |
| "add repository", "add adapter" | `NEW_ADAPTER` | Phase 4 |
| "fix", "update", "change behavior" | `MODIFY` | Assess scope first |

**For FULL_FEATURE**: Execute all phases in order. Create a task list immediately.

---

## PHASE 1: DOMAIN MODEL (`internal/domain/`)

### File Location

```
internal/domain/{aggregate}/
    entity.go          ← Aggregate root + child entities
    valueobject.go     ← Value objects
    repository.go      ← Port: repository interface
    service.go         ← Domain service (optional)
    event.go           ← Domain events (optional)
```

### 1.1 Aggregate Root Entity

```go
package order

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

// Order is the aggregate root for the order bounded context.
type Order struct {
	id        OrderID
	customer  CustomerID
	items     []LineItem
	status    Status
	total     Money
	createdAt time.Time
	updatedAt time.Time
	events    []Event
}

// New creates a new Order. Returns an error if validation fails.
func New(customer CustomerID, items []LineItem) (*Order, error) {
	if len(items) == 0 {
		return nil, errors.New("order must have at least one item")
	}

	total := calculateTotal(items)

	o := &Order{
		id:        OrderID(uuid.New()),
		customer:  customer,
		items:     copyItems(items),
		status:    StatusPending,
		total:     total,
		createdAt: time.Now(),
		updatedAt: time.Now(),
	}
	o.record(OrderCreated{OrderID: o.id, Customer: customer, Total: total})

	return o, nil
}

// Reconstitute rebuilds an Order from persistence. No validation, no events.
func Reconstitute(
	id OrderID,
	customer CustomerID,
	items []LineItem,
	status Status,
	total Money,
	createdAt, updatedAt time.Time,
) *Order {
	return &Order{
		id:        id,
		customer:  customer,
		items:     items,
		status:    status,
		total:     total,
		createdAt: createdAt,
		updatedAt: updatedAt,
	}
}

// ID returns the order identifier.
func (o *Order) ID() OrderID          { return o.id }
func (o *Order) Customer() CustomerID { return o.customer }
func (o *Order) Items() []LineItem    { return copyItems(o.items) }
func (o *Order) Status() Status       { return o.status }
func (o *Order) Total() Money         { return o.total }
func (o *Order) CreatedAt() time.Time { return o.createdAt }
func (o *Order) UpdatedAt() time.Time { return o.updatedAt }

// Confirm transitions the order to confirmed status.
func (o *Order) Confirm() error {
	if o.status != StatusPending {
		return fmt.Errorf("confirm order: %w", ErrInvalidTransition)
	}
	o.status = StatusConfirmed
	o.updatedAt = time.Now()
	o.record(OrderConfirmed{OrderID: o.id})
	return nil
}

// Cancel transitions the order to cancelled status.
func (o *Order) Cancel(reason string) error {
	if o.status == StatusCancelled || o.status == StatusDelivered {
		return fmt.Errorf("cancel order: %w", ErrInvalidTransition)
	}
	o.status = StatusCancelled
	o.updatedAt = time.Now()
	o.record(OrderCancelled{OrderID: o.id, Reason: reason})
	return nil
}

// Events returns and clears accumulated domain events.
func (o *Order) Events() []Event {
	events := o.events
	o.events = nil
	return events
}

func (o *Order) record(e Event) {
	o.events = append(o.events, e)
}

func copyItems(items []LineItem) []LineItem {
	cp := make([]LineItem, len(items))
	copy(cp, items)
	return cp
}

func calculateTotal(items []LineItem) Money {
	var total Money
	for _, item := range items {
		total = total.Add(item.Subtotal())
	}
	return total
}
```

**RULES:**
- All fields unexported. Access through getter methods only.
- Mutations through methods that enforce invariants and return `error`.
- Constructor `New(...)` validates and records creation event.
- `Reconstitute(...)` rebuilds from persistence — NO validation, NO events.
- Copy slices at boundaries (in and out) to prevent aliasing.
- Domain events accumulated internally, drained via `Events()`.
- No framework dependencies. Only standard library + `uuid`.
- No `Get` prefix on getters: `ID()` not `GetID()`.

### 1.2 Value Objects

```go
package order

import (
	"errors"
	"fmt"

	"github.com/google/uuid"
)

// OrderID uniquely identifies an order.
type OrderID uuid.UUID

// NewOrderID creates a new random OrderID.
func NewOrderID() OrderID {
	return OrderID(uuid.New())
}

// ParseOrderID parses a string into an OrderID.
func ParseOrderID(s string) (OrderID, error) {
	id, err := uuid.Parse(s)
	if err != nil {
		return OrderID{}, fmt.Errorf("parse order id: %w", err)
	}
	return OrderID(id), nil
}

// String returns the string representation.
func (id OrderID) String() string {
	return uuid.UUID(id).String()
}

// IsZero reports whether the ID is the zero value.
func (id OrderID) IsZero() bool {
	return uuid.UUID(id) == uuid.Nil
}

// Money represents a monetary amount with currency.
// Immutable — all operations return new values.
type Money struct {
	amount   int64  // cents
	currency string // ISO 4217
}

// NewMoney creates a Money value. Amount is in minor units (cents).
func NewMoney(amount int64, currency string) (Money, error) {
	if currency == "" {
		return Money{}, errors.New("currency is required")
	}
	if len(currency) != 3 {
		return Money{}, errors.New("currency must be ISO 4217 (3 letters)")
	}
	return Money{amount: amount, currency: currency}, nil
}

// Amount returns the amount in minor units.
func (m Money) Amount() int64    { return m.amount }
func (m Money) Currency() string { return m.currency }

// Add returns the sum of two Money values. Panics on currency mismatch.
func (m Money) Add(other Money) Money {
	if m.currency != other.currency {
		panic(fmt.Sprintf("cannot add %s and %s", m.currency, other.currency))
	}
	return Money{amount: m.amount + other.amount, currency: m.currency}
}

// Equal reports whether two Money values are equal.
func (m Money) Equal(other Money) bool {
	return m.amount == other.amount && m.currency == other.currency
}

// Email represents a validated email address.
type Email string

// NewEmail validates and creates an Email.
func NewEmail(s string) (Email, error) {
	// Minimal validation — real validation happens at boundaries
	if s == "" {
		return "", errors.New("email is required")
	}
	if !containsAt(s) {
		return "", fmt.Errorf("invalid email: %q", s)
	}
	return Email(s), nil
}

func (e Email) String() string { return string(e) }

func containsAt(s string) bool {
	for _, c := range s {
		if c == '@' {
			return true
		}
	}
	return false
}

// Status represents an order lifecycle state.
type Status int

const (
	StatusPending   Status = iota + 1 // start at 1, avoid zero confusion
	StatusConfirmed
	StatusShipped
	StatusDelivered
	StatusCancelled
)

func (s Status) String() string {
	switch s {
	case StatusPending:
		return "pending"
	case StatusConfirmed:
		return "confirmed"
	case StatusShipped:
		return "shipped"
	case StatusDelivered:
		return "delivered"
	case StatusCancelled:
		return "cancelled"
	default:
		return fmt.Sprintf("Status(%d)", s)
	}
}

// LineItem represents a product line in an order.
type LineItem struct {
	productID ProductID
	quantity  int
	price     Money
}

// NewLineItem creates a validated line item.
func NewLineItem(productID ProductID, quantity int, price Money) (LineItem, error) {
	if quantity <= 0 {
		return LineItem{}, errors.New("quantity must be positive")
	}
	return LineItem{productID: productID, quantity: quantity, price: price}, nil
}

func (li LineItem) ProductID() ProductID { return li.productID }
func (li LineItem) Quantity() int        { return li.quantity }
func (li LineItem) Price() Money         { return li.price }

// Subtotal returns quantity * unit price.
func (li LineItem) Subtotal() Money {
	return Money{
		amount:   li.price.amount * int64(li.quantity),
		currency: li.price.currency,
	}
}
```

**RULES:**
- Value objects are immutable. No setter methods. Operations return new values.
- Typed IDs (e.g., `OrderID`) wrap `uuid.UUID` or primitive types for type safety.
- Constructor functions (`NewX`) validate input and return `(T, error)`.
- Enums start at `iota + 1` to avoid zero-value ambiguity. Always implement `String()`.
- `Equal()` method for value comparisons where needed.

### 1.3 Repository Port (Interface)

```go
package order

import "context"

// Repository defines persistence operations for the Order aggregate.
// Defined in the domain layer — implemented by outbound adapters.
type Repository interface {
	Save(ctx context.Context, order *Order) error
	FindByID(ctx context.Context, id OrderID) (*Order, error)
	FindByCustomer(ctx context.Context, customerID CustomerID) ([]*Order, error)
	Delete(ctx context.Context, id OrderID) error
}
```

**RULES:**
- Interface in the domain package, named by role: `Repository`, not `OrderRepository` (package provides context).
- Every method takes `context.Context` as first parameter.
- Return `error` as last return value.
- Return `(*Order, error)` for queries — return `nil, ErrNotFound` when absent (not empty pointer).
- Keep interfaces small. Split read/write if consumers only need one side.

### 1.4 Domain Events

```go
package order

import "time"

// Event is the interface for all domain events in this aggregate.
type Event interface {
	EventName() string
	OccurredAt() time.Time
}

// baseEvent provides common event fields.
type baseEvent struct {
	occurredAt time.Time
}

func newBaseEvent() baseEvent {
	return baseEvent{occurredAt: time.Now()}
}

func (e baseEvent) OccurredAt() time.Time { return e.occurredAt }

// OrderCreated is raised when a new order is placed.
type OrderCreated struct {
	baseEvent
	OrderID  OrderID
	Customer CustomerID
	Total    Money
}

func (e OrderCreated) EventName() string { return "order.created" }

// OrderConfirmed is raised when an order is confirmed.
type OrderConfirmed struct {
	baseEvent
	OrderID OrderID
}

func (e OrderConfirmed) EventName() string { return "order.confirmed" }

// OrderCancelled is raised when an order is cancelled.
type OrderCancelled struct {
	baseEvent
	OrderID OrderID
	Reason  string
}

func (e OrderCancelled) EventName() string { return "order.cancelled" }
```

**RULES:**
- Domain events are value types (structs), not interfaces.
- Shared `Event` interface for polymorphism.
- Event names use `{aggregate}.{action}` format: `"order.created"`.
- Events carry data needed by handlers — no entity references, just IDs and values.
- Events are immutable once created.

### 1.5 Domain Errors

```go
package order

import "errors"

// Sentinel errors for the order aggregate.
var (
	ErrNotFound          = errors.New("order not found")
	ErrInvalidTransition = errors.New("invalid status transition")
	ErrEmptyOrder        = errors.New("order must have at least one item")
)
```

**RULES:**
- Use `errors.New` for sentinels. Exported: `ErrX`. Unexported: `errX`.
- Callers use `errors.Is(err, order.ErrNotFound)` to match.
- Custom error types for structured error data:
```go
type ValidationError struct {
	Field   string
	Message string
}

func (e *ValidationError) Error() string {
	return fmt.Sprintf("validation: %s: %s", e.Field, e.Message)
}
```

### 1.6 Domain Service (Optional)

```go
package order

import "context"

// PricingService calculates order pricing with discounts.
// Used when pricing logic spans multiple aggregates or requires external data.
type PricingService struct {
	discountPolicy DiscountPolicy
}

// DiscountPolicy is a port for discount calculation.
type DiscountPolicy interface {
	Calculate(ctx context.Context, customer CustomerID, items []LineItem) (Money, error)
}

func NewPricingService(dp DiscountPolicy) *PricingService {
	return &PricingService{discountPolicy: dp}
}

func (s *PricingService) CalculateTotal(ctx context.Context, customer CustomerID, items []LineItem) (Money, error) {
	discount, err := s.discountPolicy.Calculate(ctx, customer, items)
	if err != nil {
		return Money{}, fmt.Errorf("calculate discount: %w", err)
	}
	total := calculateTotal(items)
	return Money{
		amount:   total.amount - discount.amount,
		currency: total.currency,
	}, nil
}
```

**RULES:**
- Domain services contain logic that doesn't naturally belong to a single entity.
- Accept port interfaces (defined in domain) for external capabilities.
- Return domain types, not DTOs.

---

## PHASE 2: APPLICATION LAYER (`internal/application/`)

### File Location

```
internal/application/{aggregate}/
    command.go     ← Command structs + handlers
    query.go       ← Query structs + handlers
    dto.go         ← Input/output DTOs
```

### 2.1 Command (Write Use Case)

```go
package orderapp

import (
	"context"
	"fmt"

	"{module}/internal/domain/order"
)

// CreateOrderCommand represents the intent to create a new order.
type CreateOrderCommand struct {
	CustomerID string
	Items      []CreateOrderItem
}

type CreateOrderItem struct {
	ProductID string
	Quantity  int
	PriceCents int64
	Currency   string
}

// CreateOrderHandler handles CreateOrderCommand.
type CreateOrderHandler struct {
	repo      order.Repository
	publisher EventPublisher
}

// EventPublisher is an application port for publishing domain events.
type EventPublisher interface {
	Publish(ctx context.Context, events ...order.Event) error
}

func NewCreateOrderHandler(repo order.Repository, pub EventPublisher) *CreateOrderHandler {
	return &CreateOrderHandler{repo: repo, publisher: pub}
}

// Handle executes the create order use case.
func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) (string, error) {
	customerID, err := order.ParseCustomerID(cmd.CustomerID)
	if err != nil {
		return "", fmt.Errorf("create order: %w", err)
	}

	items := make([]order.LineItem, 0, len(cmd.Items))
	for _, i := range cmd.Items {
		productID, err := order.ParseProductID(i.ProductID)
		if err != nil {
			return "", fmt.Errorf("create order: %w", err)
		}
		price, err := order.NewMoney(i.PriceCents, i.Currency)
		if err != nil {
			return "", fmt.Errorf("create order: %w", err)
		}
		item, err := order.NewLineItem(productID, i.Quantity, price)
		if err != nil {
			return "", fmt.Errorf("create order: %w", err)
		}
		items = append(items, item)
	}

	o, err := order.New(customerID, items)
	if err != nil {
		return "", fmt.Errorf("create order: %w", err)
	}

	if err := h.repo.Save(ctx, o); err != nil {
		return "", fmt.Errorf("create order: save: %w", err)
	}

	if err := h.publisher.Publish(ctx, o.Events()...); err != nil {
		return "", fmt.Errorf("create order: publish events: %w", err)
	}

	return o.ID().String(), nil
}
```

**RULES:**
- Command structs use primitive types (strings, ints). No domain types in commands.
- Handler struct holds dependencies (ports) injected via constructor.
- Constructor: `NewXHandler(deps...)`.
- `Handle(ctx, cmd) (result, error)` — always context first, error last.
- Translate primitives → domain types at the top of Handle.
- Wrap errors with use-case context: `"create order: %w"`.
- Application layer orchestrates: validate → construct domain → persist → publish.
- Application ports (like `EventPublisher`) defined in the application layer, not domain.

### 2.2 Query (Read Use Case)

```go
package orderapp

import (
	"context"
	"fmt"

	"{module}/internal/domain/order"
)

// GetOrderQuery represents a request to retrieve an order.
type GetOrderQuery struct {
	OrderID string
}

// OrderDTO is the read-model output.
type OrderDTO struct {
	ID         string         `json:"id"`
	CustomerID string         `json:"customer_id"`
	Status     string         `json:"status"`
	Items      []LineItemDTO  `json:"items"`
	TotalCents int64          `json:"total_cents"`
	Currency   string         `json:"currency"`
	CreatedAt  string         `json:"created_at"`
}

type LineItemDTO struct {
	ProductID  string `json:"product_id"`
	Quantity   int    `json:"quantity"`
	PriceCents int64  `json:"price_cents"`
	Currency   string `json:"currency"`
}

// GetOrderHandler handles GetOrderQuery.
type GetOrderHandler struct {
	repo order.Repository
}

func NewGetOrderHandler(repo order.Repository) *GetOrderHandler {
	return &GetOrderHandler{repo: repo}
}

// Handle retrieves an order and maps to DTO.
func (h *GetOrderHandler) Handle(ctx context.Context, q GetOrderQuery) (OrderDTO, error) {
	id, err := order.ParseOrderID(q.OrderID)
	if err != nil {
		return OrderDTO{}, fmt.Errorf("get order: %w", err)
	}

	o, err := h.repo.FindByID(ctx, id)
	if err != nil {
		return OrderDTO{}, fmt.Errorf("get order: %w", err)
	}

	return toOrderDTO(o), nil
}

func toOrderDTO(o *order.Order) OrderDTO {
	items := make([]LineItemDTO, len(o.Items()))
	for i, item := range o.Items() {
		items[i] = LineItemDTO{
			ProductID:  item.ProductID().String(),
			Quantity:   item.Quantity(),
			PriceCents: item.Price().Amount(),
			Currency:   item.Price().Currency(),
		}
	}
	return OrderDTO{
		ID:         o.ID().String(),
		CustomerID: o.Customer().String(),
		Status:     o.Status().String(),
		Items:      items,
		TotalCents: o.Total().Amount(),
		Currency:   o.Total().Currency(),
		CreatedAt:  o.CreatedAt().Format("2006-01-02T15:04:05Z07:00"),
	}
}
```

**RULES:**
- Query handlers return DTOs, never domain entities.
- DTOs are plain structs with JSON tags. Serialization is an application concern.
- Map domain → DTO at the application boundary with pure functions (`toOrderDTO`).
- DTOs use primitives (strings for IDs, int64 for money, string for dates).
- For complex read models, consider a dedicated read repository (CQRS read side).

### 2.3 Application Port Interfaces

```go
// File: internal/application/port/mailer.go
package port

import "context"

// Mailer sends transactional emails.
type Mailer interface {
	SendOrderConfirmation(ctx context.Context, to string, orderID string) error
}
```

```go
// File: internal/application/port/storage.go
package port

import (
	"context"
	"io"
)

// FileStorage stores and retrieves files.
type FileStorage interface {
	Upload(ctx context.Context, key string, r io.Reader) error
	Download(ctx context.Context, key string) (io.ReadCloser, error)
}
```

**RULES:**
- Application ports are for capabilities that don't belong to the domain (email, file storage, notifications).
- Separate file per port. Package `port/`.
- Keep interfaces minimal — only methods the application actually uses.

---

## PHASE 3: INBOUND ADAPTERS (`internal/adapter/inbound/`)

### 3.1 HTTP Handler

```go
// File: internal/adapter/inbound/http/handler/order.go
package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"{module}/internal/application/orderapp"
	"{module}/internal/domain/order"
)

// OrderHandler handles HTTP requests for orders.
type OrderHandler struct {
	createOrder *orderapp.CreateOrderHandler
	getOrder    *orderapp.GetOrderHandler
}

func NewOrderHandler(
	create *orderapp.CreateOrderHandler,
	get *orderapp.GetOrderHandler,
) *OrderHandler {
	return &OrderHandler{createOrder: create, getOrder: get}
}

// Create handles POST /orders.
func (h *OrderHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	cmd := orderapp.CreateOrderCommand{
		CustomerID: req.CustomerID,
		Items:      toCommandItems(req.Items),
	}

	id, err := h.createOrder.Handle(r.Context(), cmd)
	if err != nil {
		handleAppError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"id": id})
}

// Get handles GET /orders/{id}.
func (h *OrderHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id") // Go 1.22+ stdlib

	q := orderapp.GetOrderQuery{OrderID: id}

	dto, err := h.getOrder.Handle(r.Context(), q)
	if err != nil {
		handleAppError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, dto)
}

func handleAppError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, order.ErrNotFound):
		writeError(w, http.StatusNotFound, err.Error())
	case errors.Is(err, order.ErrInvalidTransition):
		writeError(w, http.StatusConflict, err.Error())
	default:
		writeError(w, http.StatusInternalServerError, "internal error")
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
```

### 3.2 Request Types

```go
// File: internal/adapter/inbound/http/request/order.go
package request

type createOrderRequest struct {
	CustomerID string              `json:"customer_id"`
	Items      []createOrderItem   `json:"items"`
}

type createOrderItem struct {
	ProductID  string `json:"product_id"`
	Quantity   int    `json:"quantity"`
	PriceCents int64  `json:"price_cents"`
	Currency   string `json:"currency"`
}

func toCommandItems(items []createOrderItem) []orderapp.CreateOrderItem {
	result := make([]orderapp.CreateOrderItem, len(items))
	for i, item := range items {
		result[i] = orderapp.CreateOrderItem{
			ProductID:  item.ProductID,
			Quantity:   item.Quantity,
			PriceCents: item.PriceCents,
			Currency:   item.Currency,
		}
	}
	return result
}
```

### 3.3 Router

```go
// File: internal/adapter/inbound/http/router.go
package http

import (
	"net/http"

	"{module}/internal/adapter/inbound/http/handler"
	"{module}/internal/adapter/inbound/http/middleware"
)

func NewRouter(orderHandler *handler.OrderHandler) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /orders", orderHandler.Create)
	mux.HandleFunc("GET /orders/{id}", orderHandler.Get)

	// Stack middleware: outermost wraps first
	var h http.Handler = mux
	h = middleware.RequestID(h)
	h = middleware.Logger(h)
	h = middleware.Recoverer(h)

	return h
}
```

### 3.4 Middleware

```go
// File: internal/adapter/inbound/http/middleware/recoverer.go
package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"
)

// Recoverer recovers from panics and logs the stack trace.
func Recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rvr := recover(); rvr != nil {
				slog.Error("panic recovered",
					"error", rvr,
					"stack", string(debug.Stack()),
				)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}
```

**RULES:**
- HTTP handlers know about request/response and the application layer. Nothing else.
- Map HTTP request → application command/query. Map application result → HTTP response.
- Use `r.Context()` to propagate context.
- Error mapping: domain errors → HTTP status codes (central `handleAppError`).
- Use Go 1.22+ stdlib routing (`http.NewServeMux` with method+pattern) or chi/echo.
- Middleware uses the `func(http.Handler) http.Handler` pattern.
- Request types are unexported (private to the adapter). DTOs from application layer are the response.

---

## PHASE 4: OUTBOUND ADAPTERS (`internal/adapter/outbound/`)

### 4.1 Repository Implementation (PostgreSQL)

```go
// File: internal/adapter/outbound/persistence/order.go
package persistence

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"{module}/internal/domain/order"
)

// Compile-time check: PostgresOrderRepo implements order.Repository.
var _ order.Repository = (*PostgresOrderRepo)(nil)

// PostgresOrderRepo implements order.Repository using PostgreSQL via pgx.
type PostgresOrderRepo struct {
	pool *pgxpool.Pool
}

func NewPostgresOrderRepo(pool *pgxpool.Pool) *PostgresOrderRepo {
	return &PostgresOrderRepo{pool: pool}
}

func (r *PostgresOrderRepo) Save(ctx context.Context, o *order.Order) error {
	return pgx.BeginFunc(ctx, r.pool, func(tx pgx.Tx) error {
		orderQuery := `
			INSERT INTO orders (id, customer_id, status, total_cents, currency, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (id) DO UPDATE SET
				status = EXCLUDED.status,
				total_cents = EXCLUDED.total_cents,
				updated_at = EXCLUDED.updated_at`

		_, err := tx.Exec(ctx, orderQuery,
			o.ID().String(),
			o.Customer().String(),
			o.Status().String(),
			o.Total().Amount(),
			o.Total().Currency(),
			o.CreatedAt(),
			o.UpdatedAt(),
		)
		if err != nil {
			return fmt.Errorf("save order: %w", err)
		}

		for _, item := range o.Items() {
			itemQuery := `
				INSERT INTO order_items (order_id, product_id, quantity, price_cents, currency)
				VALUES ($1, $2, $3, $4, $5)
				ON CONFLICT (order_id, product_id) DO UPDATE SET
					quantity = EXCLUDED.quantity,
					price_cents = EXCLUDED.price_cents`

			_, err := tx.Exec(ctx, itemQuery,
				o.ID().String(),
				item.ProductID().String(),
				item.Quantity(),
				item.Price().Amount(),
				item.Price().Currency(),
			)
			if err != nil {
				return fmt.Errorf("save order item: %w", err)
			}
		}

		return nil
	})
}

func (r *PostgresOrderRepo) FindByID(ctx context.Context, id order.OrderID) (*order.Order, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, customer_id, status, total_cents, currency, created_at, updated_at
		FROM orders WHERE id = $1`, id.String())

	var (
		rawID, rawCustomer, rawStatus, rawCurrency string
		totalCents                                  int64
		createdAt, updatedAt                        time.Time
	)
	if err := row.Scan(&rawID, &rawCustomer, &rawStatus, &rawCurrency, &totalCents, &createdAt, &updatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, order.ErrNotFound
		}
		return nil, fmt.Errorf("find order: %w", err)
	}

	items, err := r.findItems(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find order items: %w", err)
	}

	orderID, _ := order.ParseOrderID(rawID)
	customerID, _ := order.ParseCustomerID(rawCustomer)
	status := parseStatus(rawStatus)
	total := order.Money{} // use Reconstitute-safe constructor

	return order.Reconstitute(orderID, customerID, items, status, total, createdAt, updatedAt), nil
}

func (r *PostgresOrderRepo) FindByCustomer(ctx context.Context, customerID order.CustomerID) ([]*order.Order, error) {
	// Implementation follows same pattern as FindByID with a query loop
	return nil, nil // placeholder
}

func (r *PostgresOrderRepo) Delete(ctx context.Context, id order.OrderID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM orders WHERE id = $1`, id.String())
	if err != nil {
		return fmt.Errorf("delete order: %w", err)
	}
	return nil
}

// lineItemRow maps a row from order_items to domain values.
type lineItemRow struct {
	ProductID string `db:"product_id"`
	Quantity  int    `db:"quantity"`
	PriceCents int64 `db:"price_cents"`
	Currency  string `db:"currency"`
}

func (r *PostgresOrderRepo) findItems(ctx context.Context, orderID order.OrderID) ([]order.LineItem, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT product_id, quantity, price_cents, currency
		FROM order_items WHERE order_id = $1`, orderID.String())
	if err != nil {
		return nil, err
	}

	itemRows, err := pgx.CollectRows(rows, pgx.RowToStructByName[lineItemRow])
	if err != nil {
		return nil, err
	}

	items := make([]order.LineItem, 0, len(itemRows))
	for _, r := range itemRows {
		productID, _ := order.ParseProductID(r.ProductID)
		price, _ := order.NewMoney(r.PriceCents, r.Currency)
		item, _ := order.NewLineItem(productID, r.Quantity, price)
		items = append(items, item)
	}
	return items, nil
}
```

### 4.2 In-Memory Repository (Testing)

```go
// File: internal/adapter/outbound/persistence/order_inmem.go
package persistence

import (
	"context"
	"sync"

	"{module}/internal/domain/order"
)

var _ order.Repository = (*InMemoryOrderRepo)(nil)

// InMemoryOrderRepo is a thread-safe in-memory repository for testing.
type InMemoryOrderRepo struct {
	mu     sync.RWMutex
	orders map[order.OrderID]*order.Order
}

func NewInMemoryOrderRepo() *InMemoryOrderRepo {
	return &InMemoryOrderRepo{
		orders: make(map[order.OrderID]*order.Order),
	}
}

func (r *InMemoryOrderRepo) Save(_ context.Context, o *order.Order) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.orders[o.ID()] = o
	return nil
}

func (r *InMemoryOrderRepo) FindByID(_ context.Context, id order.OrderID) (*order.Order, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	o, ok := r.orders[id]
	if !ok {
		return nil, order.ErrNotFound
	}
	return o, nil
}

func (r *InMemoryOrderRepo) FindByCustomer(_ context.Context, customerID order.CustomerID) ([]*order.Order, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var result []*order.Order
	for _, o := range r.orders {
		if o.Customer() == customerID {
			result = append(result, o)
		}
	}
	return result, nil
}

func (r *InMemoryOrderRepo) Delete(_ context.Context, id order.OrderID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.orders, id)
	return nil
}
```

### 4.3 Event Publisher Implementation

```go
// File: internal/adapter/outbound/messaging/publisher.go
package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"{module}/internal/domain/order"
)

var _ orderapp.EventPublisher = (*LogEventPublisher)(nil)

// LogEventPublisher logs events. Replace with real messaging (NATS, Kafka, RabbitMQ).
type LogEventPublisher struct {
	logger *slog.Logger
}

func NewLogEventPublisher(logger *slog.Logger) *LogEventPublisher {
	return &LogEventPublisher{logger: logger}
}

func (p *LogEventPublisher) Publish(ctx context.Context, events ...order.Event) error {
	for _, e := range events {
		data, err := json.Marshal(e)
		if err != nil {
			return fmt.Errorf("marshal event %s: %w", e.EventName(), err)
		}
		p.logger.InfoContext(ctx, "domain event published",
			"event", e.EventName(),
			"data", string(data),
		)
	}
	return nil
}
```

**RULES:**
- Every adapter struct starts with compile-time interface check: `var _ Port = (*Adapter)(nil)`.
- Constructor: `NewXAdapter(deps...)`. Dependencies are concrete infrastructure types (pgxpool.Pool, slog.Logger).
- `Reconstitute()` to rebuild domain objects from storage — never `New()` (which validates + fires events).
- In-memory adapters for testing — same interface, thread-safe with `sync.RWMutex`.
- Always `defer rows.Close()` and check `rows.Err()` after scan loop.
- Use parameterized queries (`$1`, `$2`) — NEVER string concatenation (SQL injection).

---

## PHASE 5: INFRASTRUCTURE & WIRING (`internal/infrastructure/`, `cmd/`)

### 5.1 Configuration

```go
// File: internal/infrastructure/config/config.go
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds all application configuration.
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Log      LogConfig
}

type ServerConfig struct {
	Host            string
	Port            int
	ReadTimeout     time.Duration
	WriteTimeout    time.Duration
	ShutdownTimeout time.Duration
}

type DatabaseConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	Name     string
	SSLMode  string
}

func (c DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.Name, c.SSLMode,
	)
}

type LogConfig struct {
	Level  string
	Format string // "json" or "text"
}

// Load reads configuration from environment variables.
func Load() (Config, error) {
	port, err := strconv.Atoi(envOrDefault("SERVER_PORT", "8080"))
	if err != nil {
		return Config{}, fmt.Errorf("parse SERVER_PORT: %w", err)
	}

	dbPort, err := strconv.Atoi(envOrDefault("DB_PORT", "5432"))
	if err != nil {
		return Config{}, fmt.Errorf("parse DB_PORT: %w", err)
	}

	return Config{
		Server: ServerConfig{
			Host:            envOrDefault("SERVER_HOST", "0.0.0.0"),
			Port:            port,
			ReadTimeout:     5 * time.Second,
			WriteTimeout:    10 * time.Second,
			ShutdownTimeout: 30 * time.Second,
		},
		Database: DatabaseConfig{
			Host:     envOrDefault("DB_HOST", "localhost"),
			Port:     dbPort,
			User:     envOrDefault("DB_USER", "postgres"),
			Password: os.Getenv("DB_PASSWORD"),
			Name:     envOrDefault("DB_NAME", "app"),
			SSLMode:  envOrDefault("DB_SSLMODE", "disable"),
		},
		Log: LogConfig{
			Level:  envOrDefault("LOG_LEVEL", "info"),
			Format: envOrDefault("LOG_FORMAT", "json"),
		},
	}, nil
}

func envOrDefault(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}
```

### 5.2 Database Setup

```go
// File: internal/infrastructure/database/postgres.go
package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"{module}/internal/infrastructure/config"
)

// NewPostgres creates a pgx connection pool for PostgreSQL.
func NewPostgres(ctx context.Context, cfg config.DatabaseConfig) (*pgxpool.Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(cfg.DSN())
	if err != nil {
		return nil, fmt.Errorf("parse postgres config: %w", err)
	}

	poolCfg.MaxConns = 25
	poolCfg.MinConns = 5
	poolCfg.MaxConnLifetime = 1 * time.Hour
	poolCfg.MaxConnIdleTime = 30 * time.Minute
	poolCfg.HealthCheckPeriod = 1 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("create postgres pool: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	return pool, nil
}
```

### 5.3 HTTP Server with Graceful Shutdown

```go
// File: internal/infrastructure/server/http.go
package server

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"time"
)

// HTTP wraps an http.Server with graceful shutdown.
type HTTP struct {
	srv    *http.Server
	logger *slog.Logger
}

func NewHTTP(addr string, handler http.Handler, readTimeout, writeTimeout time.Duration, logger *slog.Logger) *HTTP {
	return &HTTP{
		srv: &http.Server{
			Addr:         addr,
			Handler:      handler,
			ReadTimeout:  readTimeout,
			WriteTimeout: writeTimeout,
		},
		logger: logger,
	}
}

// Run starts the server and blocks until ctx is cancelled, then shuts down gracefully.
func (s *HTTP) Run(ctx context.Context, shutdownTimeout time.Duration) error {
	errCh := make(chan error, 1)

	go func() {
		s.logger.Info("http server starting", "addr", s.srv.Addr)
		if err := s.srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- fmt.Errorf("listen: %w", err)
		}
		close(errCh)
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		s.logger.Info("shutting down http server")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		if err := s.srv.Shutdown(shutdownCtx); err != nil {
			return fmt.Errorf("shutdown: %w", err)
		}
		return nil
	}
}
```

### 5.4 Dependency Injection (Manual Wiring)

```go
// File: internal/infrastructure/di/container.go
package di

import (
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"

	"{module}/internal/adapter/inbound/http/handler"
	"{module}/internal/adapter/outbound/messaging"
	"{module}/internal/adapter/outbound/persistence"
	"{module}/internal/application/orderapp"
)

// Container holds all wired dependencies. Build once at startup.
type Container struct {
	OrderHandler *handler.OrderHandler
}

// NewContainer wires all dependencies.
func NewContainer(pool *pgxpool.Pool, logger *slog.Logger) *Container {
	// Outbound adapters
	orderRepo := persistence.NewPostgresOrderRepo(pool)
	eventPub := messaging.NewLogEventPublisher(logger)

	// Application handlers
	createOrder := orderapp.NewCreateOrderHandler(orderRepo, eventPub)
	getOrder := orderapp.NewGetOrderHandler(orderRepo)

	// Inbound adapters
	orderHandler := handler.NewOrderHandler(createOrder, getOrder)

	return &Container{
		OrderHandler: orderHandler,
	}
}
```

### 5.5 Main Entrypoint

```go
// File: cmd/api/main.go
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"{module}/internal/adapter/inbound/http"
	"{module}/internal/infrastructure/config"
	"{module}/internal/infrastructure/database"
	"{module}/internal/infrastructure/di"
	"{module}/internal/infrastructure/server"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	// Configuration
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	// Logger
	logger := newLogger(cfg.Log)

	// Database
	pool, err := database.NewPostgres(context.Background(), cfg.Database)
	if err != nil {
		return fmt.Errorf("connect database: %w", err)
	}
	defer pool.Close()

	// Wire dependencies
	container := di.NewContainer(pool, logger)

	// HTTP router
	router := http.NewRouter(container.OrderHandler)

	// HTTP server
	addr := fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port)
	srv := server.NewHTTP(addr, router, cfg.Server.ReadTimeout, cfg.Server.WriteTimeout, logger)

	// Graceful shutdown on SIGINT/SIGTERM
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	return srv.Run(ctx, cfg.Server.ShutdownTimeout)
}

func newLogger(cfg config.LogConfig) *slog.Logger {
	var handler slog.Handler
	opts := &slog.HandlerOptions{Level: parseLogLevel(cfg.Level)}

	switch cfg.Format {
	case "text":
		handler = slog.NewTextHandler(os.Stdout, opts)
	default:
		handler = slog.NewJSONHandler(os.Stdout, opts)
	}

	return slog.New(handler)
}

func parseLogLevel(s string) slog.Level {
	switch s {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
```

**RULES:**
- `main()` calls `run()`, `run()` returns `error`. Single `os.Exit` in `main()`.
- Graceful shutdown via `signal.NotifyContext`.
- All resources opened in `run()` are deferred for cleanup: `defer db.Close()`.
- DI is manual constructor wiring — no magic, no reflection, no service locators.
- Configuration from environment. No flags in libraries (only in `cmd/`).
- Use `log/slog` (stdlib structured logging, Go 1.21+).

---

## TESTING PATTERNS

**Stack:** `testify/assert` + `testify/require` for assertions, `go.uber.org/mock/gomock` for interface mocks.
**Coverage target: minimum 95%.** Enforce with `go test -coverprofile=coverage.out ./... && go tool cover -func=coverage.out`.

### Mock Generation with mockgen

Generate mocks from port interfaces using `go:generate` directives:

```go
// File: internal/domain/order/ports.go
package order

//go:generate mockgen -source=ports.go -destination=mocks/mock_ports.go -package=mocks

type OrderRepository interface {
	FindByID(ctx context.Context, id OrderID) (*Order, error)
	Save(ctx context.Context, o *Order) error
}

type EventPublisher interface {
	Publish(ctx context.Context, events ...Event) error
}
```

Run generation:

```bash
# Generate all mocks
go generate ./...

# Or target a specific package
go generate ./internal/domain/order/...
```

**mockgen flags:**

| Flag | Purpose |
|------|---------|
| `-source` | Input file containing interfaces (source mode) |
| `-destination` | Output file path |
| `-package` | Package name for generated mocks |
| `-mock_names` | Custom mock names (e.g., `Repository=MockOrderRepo`) |
| `-typed` | Generate type-safe Return, Do, DoAndReturn functions |

**Package mode** (when interfaces span multiple files):

```bash
mockgen -destination=mocks/mock_repo.go -package=mocks {module}/internal/domain/order OrderRepository,EventPublisher
```

### Domain Unit Tests

```go
// File: internal/domain/order/entity_test.go
package order_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"{module}/internal/domain/order"
)

func TestNewOrder(t *testing.T) {
	t.Parallel()

	customerID := order.NewCustomerID()
	price, _ := order.NewMoney(1000, "USD")
	item, _ := order.NewLineItem(order.NewProductID(), 2, price)

	tests := []struct {
		name    string
		give    []order.LineItem
		wantErr bool
	}{
		{
			name:    "valid order",
			give:    []order.LineItem{item},
			wantErr: false,
		},
		{
			name:    "empty items",
			give:    nil,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, err := order.New(customerID, tt.give)

			if tt.wantErr {
				assert.Error(t, err)
				return
			}
			require.NoError(t, err)

			assert.False(t, got.ID().IsZero(), "expected non-zero ID")
			assert.Equal(t, order.StatusPending, got.Status())
			assert.Equal(t, customerID, got.Customer())
		})
	}
}

func TestOrderConfirm(t *testing.T) {
	t.Parallel()

	o := newTestOrder(t)

	require.NoError(t, o.Confirm())
	assert.Equal(t, order.StatusConfirmed, o.Status())

	// Confirm again should fail
	assert.Error(t, o.Confirm(), "expected error on double confirm")
}

func TestOrderEvents(t *testing.T) {
	t.Parallel()

	o := newTestOrder(t)
	events := o.Events()

	require.Len(t, events, 1)
	assert.Equal(t, "order.created", events[0].EventName())

	// Events should be drained
	assert.Empty(t, o.Events())
}

// newTestOrder is a test helper that creates a valid order.
func newTestOrder(t *testing.T) *order.Order {
	t.Helper()
	price, _ := order.NewMoney(1000, "USD")
	item, _ := order.NewLineItem(order.NewProductID(), 1, price)
	o, err := order.New(order.NewCustomerID(), []order.LineItem{item})
	require.NoError(t, err, "create test order")
	return o
}
```

### Application Unit Tests (gomock)

```go
// File: internal/application/orderapp/command_test.go
package orderapp_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/mock/gomock"

	"{module}/internal/application/orderapp"
	"{module}/internal/domain/order"
	"{module}/internal/domain/order/mocks"
)

func TestCreateOrderHandler_Success(t *testing.T) {
	t.Parallel()

	ctrl := gomock.NewController(t)
	repo := mocks.NewMockOrderRepository(ctrl)
	publisher := mocks.NewMockEventPublisher(ctrl)

	// Expect Save to be called once with any order
	repo.EXPECT().
		Save(gomock.Any(), gomock.Any()).
		Return(nil).
		Times(1)

	// Expect events to be published
	publisher.EXPECT().
		Publish(gomock.Any(), gomock.Any()).
		Return(nil).
		Times(1)

	handler := orderapp.NewCreateOrderHandler(repo, publisher)

	cmd := orderapp.CreateOrderCommand{
		CustomerID: "550e8400-e29b-41d4-a716-446655440000",
		Items: []orderapp.CreateOrderItem{
			{
				ProductID:  "660e8400-e29b-41d4-a716-446655440000",
				Quantity:   2,
				PriceCents: 1500,
				Currency:   "USD",
			},
		},
	}

	id, err := handler.Handle(context.Background(), cmd)
	require.NoError(t, err)
	assert.NotEmpty(t, id)
}

func TestCreateOrderHandler_SaveFails(t *testing.T) {
	t.Parallel()

	ctrl := gomock.NewController(t)
	repo := mocks.NewMockOrderRepository(ctrl)
	publisher := mocks.NewMockEventPublisher(ctrl)

	repo.EXPECT().
		Save(gomock.Any(), gomock.Any()).
		Return(errors.New("db connection lost")).
		Times(1)

	// Publisher should NOT be called when save fails
	publisher.EXPECT().
		Publish(gomock.Any(), gomock.Any()).
		Times(0)

	handler := orderapp.NewCreateOrderHandler(repo, publisher)
	cmd := orderapp.CreateOrderCommand{
		CustomerID: "550e8400-e29b-41d4-a716-446655440000",
		Items: []orderapp.CreateOrderItem{
			{ProductID: "660e8400-e29b-41d4-a716-446655440000", Quantity: 1, PriceCents: 1000, Currency: "USD"},
		},
	}

	_, err := handler.Handle(context.Background(), cmd)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "db connection lost")
}

func TestCreateOrderHandler_InvalidCommand(t *testing.T) {
	t.Parallel()

	ctrl := gomock.NewController(t)
	repo := mocks.NewMockOrderRepository(ctrl)
	publisher := mocks.NewMockEventPublisher(ctrl)

	// Neither Save nor Publish should be called for invalid input
	handler := orderapp.NewCreateOrderHandler(repo, publisher)

	cmd := orderapp.CreateOrderCommand{
		CustomerID: "invalid-uuid",
		Items:      nil, // empty items
	}

	_, err := handler.Handle(context.Background(), cmd)
	assert.Error(t, err)
}
```

### gomock Patterns Reference

```go
// Exact argument matching
repo.EXPECT().FindByID(gomock.Any(), gomock.Eq(expectedID)).Return(order, nil)

// Any argument
repo.EXPECT().Save(gomock.Any(), gomock.Any()).Return(nil)

// Call count constraints
repo.EXPECT().Save(gomock.Any(), gomock.Any()).Return(nil).Times(1)
repo.EXPECT().FindByID(gomock.Any(), gomock.Any()).Return(order, nil).AnyTimes()

// DoAndReturn for dynamic behavior
repo.EXPECT().
	Save(gomock.Any(), gomock.Any()).
	DoAndReturn(func(ctx context.Context, o *order.Order) error {
		assert.Equal(t, order.StatusPending, o.Status())
		return nil
	})

// Ordered expectations
gomock.InOrder(
	repo.EXPECT().Save(gomock.Any(), gomock.Any()).Return(nil),
	publisher.EXPECT().Publish(gomock.Any(), gomock.Any()).Return(nil),
)
```

### Testing Rules Summary

| Rule | Detail |
|------|--------|
| Coverage | **Minimum 95%.** Enforced in CI: `go test -coverprofile=coverage.out ./...` |
| Assertions | `testify/require` for setup and preconditions (fail-fast). `testify/assert` for verifications (continue on fail). |
| Mocks | `go.uber.org/mock/gomock` + `mockgen` for port interfaces. Generate with `go:generate`. |
| Domain tests | Pure unit tests with `assert`/`require`. No mocks, no I/O. Test invariants and state transitions. |
| Application tests | Use gomock to mock port interfaces. Test use-case orchestration, error paths, and edge cases. |
| Adapter tests | Integration tests against real infrastructure (testcontainers). |
| Test helpers | Call `t.Helper()`. Use `require` for setup failures. |
| Parallel | Use `t.Parallel()` in all tests and subtests where safe. |
| Naming | `Test{Type}_{Scenario}` (e.g., `TestCreateOrderHandler_SaveFails`) |
| Package | `package foo_test` for public API tests. `package foo` when testing unexported internals. |
| Mock location | `internal/domain/{aggregate}/mocks/` for port mocks. Add `mocks/` to `.gitignore` if generated in CI. |

---

## ANTI-PATTERNS CHECKLIST

Before finishing any implementation, verify NONE of these exist:

| Anti-Pattern | Why It's Wrong | Fix |
|-------------|----------------|-----|
| Domain imports `database/sql`, `pgx`, or any adapter package | Violates dependency rule | Define port interface in domain, implement in adapter |
| Application imports adapter package | Violates dependency rule | Use port interfaces |
| Entity with exported fields | Breaks encapsulation | Unexported fields + getter methods |
| Entity modified directly (no method) | Bypasses invariant enforcement | Mutation methods with validation |
| `New()` used for reconstitution from DB | Fires domain events on load, validates already-valid data | Use `Reconstitute()` |
| Interface defined next to its only implementation | Producer-side interface — Go anti-pattern | Consumer defines the interface |
| Interface with 10+ methods | Too large — hard to implement, test, and compose | Split into focused interfaces |
| `Get` prefix on getters | Not idiomatic Go | Drop the prefix: `Name()` not `GetName()` |
| Error logged AND returned | Double-reporting | Choose one: log or return |
| Panic in application/domain code | Crashes the process | Return `error` |
| `init()` with side effects | Hidden, ordering-dependent, hard to test | Explicit initialization in constructors |
| Mutable package-level variables | Global state — race conditions, testing nightmares | Inject dependencies |
| `snake_case` names | Not Go style | Use `MixedCaps` / `mixedCaps` |
| `reflect.DeepEqual` in tests | Panics on cycles, no diff output | Use `assert.Equal` / `require.Equal` from testify |
| Raw `if/t.Errorf` in tests | Verbose, inconsistent assertion style | Use `testify/assert` and `testify/require` |
| HTTP handler calls DB directly | Skips application layer | Handler → Command/Query → Repository |
| Business logic in HTTP handler | Leaks domain rules into adapter | Move to domain entity or application handler |
| SQL with string concatenation | SQL injection vulnerability | Use parameterized queries (`$1`, `$2`) |
| `context.Background()` in library code | Ignores caller's cancellation/deadline | Accept `context.Context` parameter |
| Fire-and-forget goroutine | Leak, no error handling, no shutdown | Managed lifecycle with WaitGroup or done channel |

---

## ADVANCED PATTERNS

### CQRS with Go Generics

Use Go generics to define a reusable command/query handler contract. Each use case is a standalone struct implementing the generic interface.

```go
// File: internal/application/core/handler.go
package core

import "context"

// CommandHandler handles a command that mutates state.
// C = command type, R = result type.
type CommandHandler[C any, R any] interface {
	Handle(ctx context.Context, cmd C) (R, error)
}

// QueryHandler handles a read-only query.
// Q = query type, R = result type.
type QueryHandler[Q any, R any] interface {
	Handle(ctx context.Context, query Q) (R, error)
}
```

Then each use case is a concrete type:

```go
// File: internal/application/order/create.go
package orderapp

type CreateOrderHandler struct {
	repo      order.Repository
	publisher EventPublisher
}

// Compile-time check against the generic interface.
var _ core.CommandHandler[CreateOrderCommand, string] = (*CreateOrderHandler)(nil)

func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) (string, error) {
	// ... orchestration logic
}
```

**RULES:**
- Each command/query is a separate file: `create.go`, `get.go`, `update.go`, `delete.go`.
- Input DTOs are primitives-only structs (no domain types in commands/queries).
- Output DTOs for queries. Plain types (string ID, bool) for commands.
- Generic interfaces enable decorators (see below).

### Use Case Decorators (Cross-Cutting Concerns)

Wrap command/query handlers with logging, metrics, and transaction decorators without modifying the handler itself.

```go
// File: internal/application/core/decorator.go
package core

import (
	"context"
	"log/slog"
	"time"
)

// loggingCommandDecorator wraps a CommandHandler with structured logging.
type loggingCommandDecorator[C any, R any] struct {
	base   CommandHandler[C, R]
	logger *slog.Logger
}

func (d *loggingCommandDecorator[C, R]) Handle(ctx context.Context, cmd C) (R, error) {
	d.logger.Info("executing command",
		"command", commandName(cmd),
	)
	start := time.Now()

	result, err := d.base.Handle(ctx, cmd)

	if err != nil {
		d.logger.Error("command failed",
			"command", commandName(cmd),
			"duration", time.Since(start),
			"error", err,
		)
	} else {
		d.logger.Info("command succeeded",
			"command", commandName(cmd),
			"duration", time.Since(start),
		)
	}
	return result, err
}

// metricsCommandDecorator wraps a CommandHandler with metrics recording.
type metricsCommandDecorator[C any, R any] struct {
	base CommandHandler[C, R]
}

func (d *metricsCommandDecorator[C, R]) Handle(ctx context.Context, cmd C) (R, error) {
	start := time.Now()
	result, err := d.base.Handle(ctx, cmd)
	// Record duration, success/failure in Prometheus, OpenTelemetry, etc.
	_ = time.Since(start)
	return result, err
}

// ApplyCommandDecorators wraps a handler with standard decorators.
func ApplyCommandDecorators[C any, R any](
	handler CommandHandler[C, R],
	logger *slog.Logger,
) CommandHandler[C, R] {
	return &loggingCommandDecorator[C, R]{
		base:   &metricsCommandDecorator[C, R]{base: handler},
		logger: logger,
	}
}

func commandName(cmd any) string {
	return fmt.Sprintf("%T", cmd)
}
```

Usage when wiring:

```go
createHandler := core.ApplyCommandDecorators[orderapp.CreateOrderCommand, string](
	orderapp.NewCreateOrderHandler(repo, pub),
	logger,
)
```

**RULES:**
- Decorators implement the same generic interface as the handler they wrap.
- Stack order: outermost = logging, inner = metrics, innermost = actual handler.
- Keep authoring and review as separate passes — decorators add observability without touching business logic.
- Use for: logging, metrics, tracing, transaction management, authorization.

### Domain Event Bus

Decouple side effects from the main use case flow using an event bus.

```go
// File: internal/domain/shared/event.go
package shared

import (
	"context"
	"time"
)

// DomainEvent is the base interface for all domain events.
type DomainEvent interface {
	EventName() string
	OccurredAt() time.Time
	AggregateID() string
}

// EventHandler processes a single event type.
type EventHandler interface {
	Handle(ctx context.Context, event DomainEvent) error
}

// EventBus dispatches domain events to registered handlers.
type EventBus interface {
	Publish(ctx context.Context, events ...DomainEvent) error
	Subscribe(eventName string, handler EventHandler)
}
```

```go
// File: internal/infrastructure/eventbus/inmemory.go
package eventbus

import (
	"context"
	"fmt"
	"log/slog"
	"sync"

	"{module}/internal/domain/shared"
)

var _ shared.EventBus = (*InMemoryEventBus)(nil)

// InMemoryEventBus dispatches events synchronously in-process.
type InMemoryEventBus struct {
	mu       sync.RWMutex
	handlers map[string][]shared.EventHandler
	logger   *slog.Logger
}

func NewInMemoryEventBus(logger *slog.Logger) *InMemoryEventBus {
	return &InMemoryEventBus{
		handlers: make(map[string][]shared.EventHandler),
		logger:   logger,
	}
}

func (b *InMemoryEventBus) Subscribe(eventName string, handler shared.EventHandler) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.handlers[eventName] = append(b.handlers[eventName], handler)
}

func (b *InMemoryEventBus) Publish(ctx context.Context, events ...shared.DomainEvent) error {
	b.mu.RLock()
	defer b.mu.RUnlock()

	for _, event := range events {
		handlers, ok := b.handlers[event.EventName()]
		if !ok {
			continue
		}
		for _, h := range handlers {
			if err := h.Handle(ctx, event); err != nil {
				b.logger.Error("event handler failed",
					"event", event.EventName(),
					"error", err,
				)
				return fmt.Errorf("handle event %s: %w", event.EventName(), err)
			}
		}
	}
	return nil
}
```

```go
// File: internal/infrastructure/eventbus/async.go
package eventbus

import (
	"context"
	"log/slog"
	"sync"

	"{module}/internal/domain/shared"
)

// AsyncEventBus dispatches events asynchronously with a worker pool.
type AsyncEventBus struct {
	inner   *InMemoryEventBus
	queue   chan shared.DomainEvent
	wg      sync.WaitGroup
	logger  *slog.Logger
}

func NewAsyncEventBus(inner *InMemoryEventBus, workers, bufferSize int, logger *slog.Logger) *AsyncEventBus {
	bus := &AsyncEventBus{
		inner:  inner,
		queue:  make(chan shared.DomainEvent, bufferSize),
		logger: logger,
	}
	for i := 0; i < workers; i++ {
		bus.wg.Add(1)
		go bus.worker()
	}
	return bus
}

func (b *AsyncEventBus) worker() {
	defer b.wg.Done()
	for event := range b.queue {
		if err := b.inner.Publish(context.Background(), event); err != nil {
			b.logger.Error("async event handler failed", "event", event.EventName(), "error", err)
		}
	}
}

func (b *AsyncEventBus) Publish(ctx context.Context, events ...shared.DomainEvent) error {
	for _, event := range events {
		select {
		case b.queue <- event:
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return nil
}

func (b *AsyncEventBus) Subscribe(eventName string, handler shared.EventHandler) {
	b.inner.Subscribe(eventName, handler)
}

// Shutdown drains the queue and waits for all workers to finish.
func (b *AsyncEventBus) Shutdown() {
	close(b.queue)
	b.wg.Wait()
}
```

**RULES:**
- `EventBus` is a port defined in domain. Implementations live in infrastructure.
- `InMemoryEventBus` for synchronous in-process dispatch. Use when handlers must run within the same transaction boundary.
- `AsyncEventBus` for background processing. Wraps the sync bus with a buffered channel + worker pool. Provides `Shutdown()` for graceful drain.
- Handlers subscribed by event name at startup (in DI wiring).
- Entity accumulates events → use case calls `eventBus.Publish(ctx, entity.Events()...)` after persistence.

### Transaction Management

Abstract transactions behind a port so use cases remain infrastructure-agnostic.

```go
// File: internal/domain/shared/transaction.go
package shared

import "context"

// Transaction represents an active database transaction.
type Transaction interface {
	Commit() error
	Rollback() error
}

// TransactionFactory creates transactions. Defined in domain, implemented by adapter.
type TransactionFactory interface {
	Begin(ctx context.Context) (Transaction, error)
}

// NoopTransaction is a no-op for testing.
type NoopTransaction struct{}

func (NoopTransaction) Commit() error   { return nil }
func (NoopTransaction) Rollback() error { return nil }
```

```go
// File: internal/application/core/transactional.go
package core

import (
	"context"
	"fmt"

	"{module}/internal/domain/shared"
)

// ExecuteInTransaction wraps a function in a transaction with automatic commit/rollback.
func ExecuteInTransaction(ctx context.Context, factory shared.TransactionFactory, fn func(ctx context.Context) error) error {
	tx, err := factory.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}

	if err := fn(ctx); err != nil {
		if rbErr := tx.Rollback(); rbErr != nil {
			return fmt.Errorf("rollback failed: %v (original: %w)", rbErr, err)
		}
		return err
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
	}
	return nil
}
```

Usage in a command handler:

```go
func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) (string, error) {
	var orderID string

	err := core.ExecuteInTransaction(ctx, h.txFactory, func(ctx context.Context) error {
		o, err := order.New(customerID, items)
		if err != nil {
			return err
		}
		if err := h.repo.Save(ctx, o); err != nil {
			return err
		}
		orderID = o.ID().String()
		return nil
	})
	if err != nil {
		return "", fmt.Errorf("create order: %w", err)
	}

	// Publish events AFTER transaction commits
	_ = h.publisher.Publish(ctx, events...)

	return orderID, nil
}
```

**RULES:**
- `Transaction` and `TransactionFactory` are ports in domain.
- `ExecuteInTransaction` handles commit/rollback automatically.
- Publish domain events AFTER the transaction commits (avoid publishing events for rolled-back operations).
- Use `NoopTransaction` in unit tests.
- For GORM/sqlx: pass `*gorm.DB` or `pgx.Tx` through context in the adapter implementation.

### Application Factory

Centralize use case creation when the project grows beyond a handful of handlers.

```go
// File: internal/application/factory.go
package application

import (
	"log/slog"

	"{module}/internal/application/core"
	"{module}/internal/application/orderapp"
	"{module}/internal/domain/order"
	"{module}/internal/domain/shared"
)

// Commands aggregates all command handlers.
type Commands struct {
	CreateOrder core.CommandHandler[orderapp.CreateOrderCommand, string]
	ConfirmOrder core.CommandHandler[orderapp.ConfirmOrderCommand, struct{}]
	CancelOrder  core.CommandHandler[orderapp.CancelOrderCommand, struct{}]
}

// Queries aggregates all query handlers.
type Queries struct {
	GetOrder      core.QueryHandler[orderapp.GetOrderQuery, orderapp.OrderDTO]
	ListOrders    core.QueryHandler[orderapp.ListOrdersQuery, []orderapp.OrderDTO]
}

// Application is the entry point for all use cases.
type Application struct {
	Commands Commands
	Queries  Queries
}

// NewApplication wires all use cases with decorators.
func NewApplication(
	repo order.Repository,
	pub orderapp.EventPublisher,
	txFactory shared.TransactionFactory,
	logger *slog.Logger,
) *Application {
	return &Application{
		Commands: Commands{
			CreateOrder: core.ApplyCommandDecorators(
				orderapp.NewCreateOrderHandler(repo, pub, txFactory),
				logger,
			),
			ConfirmOrder: core.ApplyCommandDecorators(
				orderapp.NewConfirmOrderHandler(repo, pub),
				logger,
			),
			CancelOrder: core.ApplyCommandDecorators(
				orderapp.NewCancelOrderHandler(repo, pub),
				logger,
			),
		},
		Queries: Queries{
			GetOrder: core.ApplyQueryDecorators(
				orderapp.NewGetOrderHandler(repo),
				logger,
			),
			ListOrders: core.ApplyQueryDecorators(
				orderapp.NewListOrdersHandler(repo),
				logger,
			),
		},
	}
}
```

HTTP handlers then receive the `Application` struct:

```go
type OrderHandler struct {
	app *application.Application
}

func (h *OrderHandler) Create(w http.ResponseWriter, r *http.Request) {
	// ...parse request...
	id, err := h.app.Commands.CreateOrder.Handle(r.Context(), cmd)
	// ...write response...
}
```

**RULES:**
- `Application` struct is the single entry point from adapters to use cases.
- Group handlers into `Commands` and `Queries` structs.
- Decorators applied at factory level — handlers stay pure.
- HTTP handlers depend on `*Application`, not individual handler structs.

### Google Wire Dependency Injection

For larger projects, use [Google Wire](https://github.com/google/wire) for compile-time DI instead of manual wiring.

```go
// File: internal/infrastructure/di/wire.go
//go:build wireinject

package di

import (
	"github.com/google/wire"

	"{module}/internal/adapter/inbound/http/handler"
	"{module}/internal/adapter/outbound/persistence"
	"{module}/internal/adapter/outbound/messaging"
	"{module}/internal/application"
	"{module}/internal/infrastructure/config"
	"{module}/internal/infrastructure/database"
	"{module}/internal/infrastructure/server"
)

// Each package exports a wire.NewSet with its providers.

var PersistenceSet = wire.NewSet(
	persistence.NewPostgresOrderRepo,
	wire.Bind(new(order.Repository), new(*persistence.PostgresOrderRepo)),
)

var MessagingSet = wire.NewSet(
	messaging.NewLogEventPublisher,
	wire.Bind(new(orderapp.EventPublisher), new(*messaging.LogEventPublisher)),
)

var ApplicationSet = wire.NewSet(
	application.NewApplication,
)

var HandlerSet = wire.NewSet(
	handler.NewOrderHandler,
)

// InitializeServer is the Wire injector function.
func InitializeServer(ctx context.Context) (*server.HTTP, error) {
	wire.Build(
		config.Load,
		database.NewPostgres,
		PersistenceSet,
		MessagingSet,
		ApplicationSet,
		HandlerSet,
		NewRouter,
		server.NewHTTP,
	)
	return nil, nil
}
```

Generate with: `wire ./internal/infrastructure/di/`

**RULES:**
- Each package exports a `wire.NewSet(...)` with its providers.
- Use `wire.Bind` to map concrete types to interfaces.
- The injector file uses `//go:build wireinject` build tag.
- Wire generates `wire_gen.go` — commit it to version control.
- Manual wiring is fine for small projects. Switch to Wire when the DI graph exceeds ~15 constructors.

### Provider Pattern (Testability)

Abstract non-deterministic dependencies (time, UUIDs, random) behind provider interfaces.

```go
// File: internal/domain/shared/provider.go
package shared

import (
	"time"

	"github.com/google/uuid"
)

// TimeProvider abstracts time.Now for testability.
type TimeProvider interface {
	Now() time.Time
}

// RealTimeProvider returns actual system time.
type RealTimeProvider struct{}

func (RealTimeProvider) Now() time.Time { return time.Now() }

// UUIDProvider abstracts UUID generation for testability.
type UUIDProvider interface {
	New() uuid.UUID
}

// RealUUIDProvider returns real UUIDs.
type RealUUIDProvider struct{}

func (RealUUIDProvider) New() uuid.UUID { return uuid.New() }
```

Generate mocks with `mockgen`:

```go
// File: internal/domain/shared/provider.go (add go:generate directive)
//go:generate mockgen -source=provider.go -destination=mocks/mock_provider.go -package=mocks
```

Use in tests:

```go
import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"go.uber.org/mock/gomock"

	"{module}/internal/domain/shared/mocks"
)

func TestSomethingWithTime(t *testing.T) {
	ctrl := gomock.NewController(t)
	tp := mocks.NewMockTimeProvider(ctrl)
	up := mocks.NewMockUUIDProvider(ctrl)

	fixedTime := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	fixedID := uuid.MustParse("550e8400-e29b-41d4-a716-446655440000")

	tp.EXPECT().Now().Return(fixedTime).AnyTimes()
	up.EXPECT().New().Return(fixedID).AnyTimes()

	// Use tp and up in your test subject...
}
```

Inject providers into entities/services that need them:

```go
func New(customer CustomerID, items []LineItem, tp shared.TimeProvider, up shared.UUIDProvider) (*Order, error) {
	// Use tp.Now() instead of time.Now()
	// Use up.New() instead of uuid.New()
}
```

**RULES:**
- Define provider interfaces in `domain/shared/`.
- Real implementations for production, gomock mocks for tests.
- Generate mocks with `mockgen` — never hand-write mock implementations.
- Only abstract what you actually need to control in tests (time, UUIDs, random). Don't over-abstract.
- Alternative: accept `func() time.Time` closures for simpler cases.

### Architecture Validation (CI Enforcement)

Enforce dependency rules automatically by scanning Go imports at test/CI time.

```go
// File: internal/infrastructure/archtest/arch_test.go
package archtest

import (
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestDependencyRules ensures inner layers never import outer layers.
func TestDependencyRules(t *testing.T) {
	t.Parallel()

	module := "github.com/yourorg/yourproject"

	rules := []struct {
		name       string
		pkg        string
		disallowed []string
	}{
		{
			name:       "domain must not import application",
			pkg:        "internal/domain",
			disallowed: []string{"internal/application", "internal/adapter", "internal/infrastructure"},
		},
		{
			name:       "application must not import adapters",
			pkg:        "internal/application",
			disallowed: []string{"internal/adapter", "internal/infrastructure"},
		},
		{
			name:       "domain must not import third-party DB/HTTP",
			pkg:        "internal/domain",
			disallowed: []string{"database/sql", "net/http", "gorm.io", "github.com/gin-gonic", "github.com/jackc/pgx"},
		},
	}

	root := findModuleRoot(t)

	for _, rule := range rules {
		t.Run(rule.name, func(t *testing.T) {
			t.Parallel()
			pkgDir := filepath.Join(root, rule.pkg)
			imports := collectImports(t, pkgDir)

			for _, imp := range imports {
				for _, disallowed := range rule.disallowed {
					full := module + "/" + disallowed
					if strings.HasPrefix(imp, full) || imp == disallowed {
						t.Errorf("forbidden import: %s imports %s", rule.pkg, imp)
					}
				}
			}
		})
	}
}

func collectImports(t *testing.T, dir string) []string {
	t.Helper()
	var imports []string
	fset := token.NewFileSet()

	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || !strings.HasSuffix(path, ".go") {
			return err
		}
		f, err := parser.ParseFile(fset, path, nil, parser.ImportsOnly)
		if err != nil {
			return err
		}
		for _, imp := range f.Imports {
			imports = append(imports, strings.Trim(imp.Path.Value, `"`))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk %s: %v", dir, err)
	}
	return imports
}

func findModuleRoot(t *testing.T) string {
	t.Helper()
	dir, _ := os.Getwd()
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("go.mod not found")
		}
		dir = parent
	}
}
```

**RULES:**
- Place in `internal/infrastructure/archtest/` or a top-level `archtest/` package.
- Run with every `go test ./...` — violations break the build.
- Check both internal layer imports and external package imports (no `database/sql` or `pgx` in domain).
- This is the automated enforcement of the dependency law table from the Architecture Rules section.

### Health Checks / Probes

Kubernetes-ready liveness and readiness endpoints.

```go
// File: internal/adapter/inbound/http/handler/health.go
package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// HealthHandler provides liveness and readiness probes.
type HealthHandler struct {
	pool *pgxpool.Pool
}

func NewHealthHandler(pool *pgxpool.Pool) *HealthHandler {
	return &HealthHandler{pool: pool}
}

// Liveness indicates the process is running. Always returns 200.
func (h *HealthHandler) Liveness(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "alive"})
}

// Readiness checks if the service can handle traffic (DB reachable, etc.).
func (h *HealthHandler) Readiness(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	checks := map[string]string{}
	status := http.StatusOK

	if err := h.pool.Ping(ctx); err != nil {
		checks["database"] = err.Error()
		status = http.StatusServiceUnavailable
	} else {
		checks["database"] = "ok"
	}

	checks["status"] = "ready"
	if status != http.StatusOK {
		checks["status"] = "not ready"
	}

	writeJSON(w, status, checks)
}
```

Register in router:

```go
mux.HandleFunc("GET /healthz", healthHandler.Liveness)
mux.HandleFunc("GET /readyz", healthHandler.Readiness)
```

**RULES:**
- `/healthz` (liveness): always 200 if process is alive. No external checks.
- `/readyz` (readiness): check DB, cache, external dependencies. Return 503 if any are down.
- Timeout readiness checks (2-5s) to prevent hanging.
- Do NOT put health endpoints behind authentication middleware.

### Structured Error Types (Application-Level)

For larger projects, use a typed error system that maps cleanly to HTTP status codes and API error responses.

```go
// File: internal/application/core/apperror.go
package core

import "fmt"

// ErrorType classifies application errors for consistent HTTP/gRPC mapping.
type ErrorType int

const (
	ErrorTypeValidation   ErrorType = iota + 1 // 400 Bad Request
	ErrorTypeNotFound                          // 404 Not Found
	ErrorTypeConflict                          // 409 Conflict
	ErrorTypeUnauthorized                      // 401 Unauthorized
	ErrorTypeForbidden                         // 403 Forbidden
	ErrorTypePersistence                       // 500 Internal Server Error
	ErrorTypeSystem                            // 500 Internal Server Error
)

// AppError is a structured error with type, message, and optional cause.
type AppError struct {
	Type    ErrorType
	Message string
	Cause   error
}

func (e *AppError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("%s: %v", e.Message, e.Cause)
	}
	return e.Message
}

func (e *AppError) Unwrap() error { return e.Cause }

// Constructor helpers.
func NewValidationError(msg string) *AppError {
	return &AppError{Type: ErrorTypeValidation, Message: msg}
}

func NewNotFoundError(msg string) *AppError {
	return &AppError{Type: ErrorTypeNotFound, Message: msg}
}

func NewConflictError(msg string) *AppError {
	return &AppError{Type: ErrorTypeConflict, Message: msg}
}

func WrapPersistenceError(err error, msg string) *AppError {
	return &AppError{Type: ErrorTypePersistence, Message: msg, Cause: err}
}

// StatusCode maps the error type to an HTTP status code.
func (e *AppError) StatusCode() int {
	switch e.Type {
	case ErrorTypeValidation:
		return 400
	case ErrorTypeNotFound:
		return 404
	case ErrorTypeConflict:
		return 409
	case ErrorTypeUnauthorized:
		return 401
	case ErrorTypeForbidden:
		return 403
	default:
		return 500
	}
}
```

Update the HTTP error handler to use it:

```go
func handleAppError(w http.ResponseWriter, err error) {
	var appErr *core.AppError
	if errors.As(err, &appErr) {
		writeError(w, appErr.StatusCode(), appErr.Message)
		return
	}
	// Fallback for untyped errors
	writeError(w, http.StatusInternalServerError, "internal error")
}
```

**RULES:**
- `AppError` lives in the application layer — it bridges domain errors and HTTP/gRPC responses.
- Use `errors.As(err, &appErr)` in handlers for type-safe matching.
- Domain sentinel errors can be wrapped: `if errors.Is(err, order.ErrNotFound) { return NewNotFoundError("order not found") }`.
- Never expose internal error details in API responses. Log the cause, return the message.

### Integration Testing with Testcontainers

Spin up real databases in tests for adapter-layer integration testing.

```go
// File: internal/adapter/outbound/persistence/order_integration_test.go
//go:build integration

package persistence_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"

	"{module}/internal/adapter/outbound/persistence"
	"{module}/internal/domain/order"
)

func setupPostgres(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx := context.Background()

	container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: testcontainers.ContainerRequest{
			Image:        "postgres:16-alpine",
			ExposedPorts: []string{"5432/tcp"},
			Env: map[string]string{
				"POSTGRES_USER":     "test",
				"POSTGRES_PASSWORD": "test",
				"POSTGRES_DB":       "testdb",
			},
			WaitingFor: wait.ForListeningPort("5432/tcp"),
		},
		Started: true,
	})
	require.NoError(t, err, "start postgres container")
	t.Cleanup(func() { container.Terminate(ctx) })

	host, _ := container.Host(ctx)
	port, _ := container.MappedPort(ctx, "5432")
	dsn := fmt.Sprintf("postgres://test:test@%s:%s/testdb?sslmode=disable", host, port.Port())

	pool, err := pgxpool.New(ctx, dsn)
	require.NoError(t, err, "create pgx pool")
	t.Cleanup(func() { pool.Close() })

	runMigrations(t, pool)

	return pool
}

func runMigrations(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	_, err := pool.Exec(context.Background(), `
		CREATE TABLE IF NOT EXISTS orders (
			id TEXT PRIMARY KEY,
			customer_id TEXT NOT NULL,
			status TEXT NOT NULL,
			total_cents BIGINT NOT NULL,
			currency TEXT NOT NULL,
			created_at TIMESTAMPTZ NOT NULL,
			updated_at TIMESTAMPTZ NOT NULL
		);
		CREATE TABLE IF NOT EXISTS order_items (
			order_id TEXT NOT NULL REFERENCES orders(id),
			product_id TEXT NOT NULL,
			quantity INT NOT NULL,
			price_cents BIGINT NOT NULL,
			currency TEXT NOT NULL,
			PRIMARY KEY (order_id, product_id)
		);
	`)
	require.NoError(t, err, "run migrations")
}

func TestPostgresOrderRepo_SaveAndFind(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	pool := setupPostgres(t)
	repo := persistence.NewPostgresOrderRepo(pool)
	ctx := context.Background()

	// Create and save
	price, _ := order.NewMoney(1500, "USD")
	item, _ := order.NewLineItem(order.NewProductID(), 2, price)
	o, _ := order.New(order.NewCustomerID(), []order.LineItem{item})

	require.NoError(t, repo.Save(ctx, o), "Save()")

	// Find by ID
	got, err := repo.FindByID(ctx, o.ID())
	require.NoError(t, err, "FindByID()")
	assert.Equal(t, o.ID(), got.ID())

	// Not found
	_, err = repo.FindByID(ctx, order.NewOrderID())
	assert.ErrorIs(t, err, order.ErrNotFound)
}
```

**RULES:**
- Use `//go:build integration` build tag. Run with `go test -tags=integration ./...`.
- Use `testcontainers-go` to spin up real PostgreSQL, Redis, etc.
- `t.Cleanup()` ensures containers are terminated even on test failure.
- Run migrations in test setup, not in production init.
- Skip with `testing.Short()` for fast local development cycles.
- Integration tests live alongside the adapter they test, not in a separate `tests/` directory.

### Converter Pattern (DTO Mapping)

For complex projects, extract DTO-to-domain and domain-to-DTO conversions into dedicated converter types.

```go
// File: internal/adapter/inbound/http/converter/order.go
package converter

import (
	"{module}/internal/adapter/inbound/http/request"
	"{module}/internal/application/orderapp"
)

// OrderConverter maps HTTP requests to application commands/queries.
type OrderConverter struct{}

func (c *OrderConverter) ToCreateCommand(req request.CreateOrder) orderapp.CreateOrderCommand {
	items := make([]orderapp.CreateOrderItem, len(req.Items))
	for i, item := range req.Items {
		items[i] = orderapp.CreateOrderItem{
			ProductID:  item.ProductID,
			Quantity:   item.Quantity,
			PriceCents: item.PriceCents,
			Currency:   item.Currency,
		}
	}
	return orderapp.CreateOrderCommand{
		CustomerID: req.CustomerID,
		Items:      items,
	}
}
```

**RULES:**
- Converters live in the adapter layer (they know both request types and application DTOs).
- Pure functions or stateless structs — no side effects.
- Name methods `To{Target}`: `ToCreateCommand`, `ToOrderDTO`, `ToResponse`.
- Use converters when mapping is complex (>5 fields, nested structs). Inline mapping for simple cases.

---

## RECOMMENDED PACKAGES & TECHNIQUES

Use these production-grade packages and runtime techniques when building Go projects in this architecture.

### Package Map (Quick Reference)

| Concern | Package | Why |
|---------|---------|-----|
| HTTP Framework | `github.com/gofiber/fiber/v3` | FastHTTP-based, Express-like API, zero-alloc JSON, type-safe generics |
| Configuration | `github.com/spf13/viper` | Multi-source (YAML, env, flags, remote), hot-reload, struct unmarshaling |
| Structured Logging | `go.uber.org/zap` | Zero-allocation Logger, 10x faster than stdlib, typed fields, sampling |
| Tracing | `go.opentelemetry.io/otel` | Vendor-neutral distributed tracing, W3C TraceContext propagation |
| Metrics | `go.opentelemetry.io/otel` + Prometheus exporter | Counters, histograms, gauges with OTel SDK + Prometheus pull |
| Log Correlation | `go.opentelemetry.io/contrib/bridges/otelslog` | Bridge slog/zap logs into OTel pipeline with trace context |
| JSON | `github.com/goccy/go-json` | Drop-in `encoding/json` replacement, 2-3x faster encode/decode |
| Profiling | `runtime/pprof` + `net/http/pprof` | CPU/memory profiling, flame graphs, heap analysis |
| GC Tuning | `GOGC` + `GOMEMLIMIT` | Control GC frequency and memory ceiling in containers |
| Race Detection | `go build -race` | ThreadSanitizer-based race detector for development/CI |
| UUID | `github.com/google/uuid` | RFC 4122 UUIDs, typed IDs |
| Redis | `github.com/redis/rueidis` | High-perf client, auto pipelining, client-side caching, cluster/sentinel |
| Redis Lock | `github.com/redis/rueidis/rueidislock` | Distributed locks built on rueidis |
| Redis OTel | `github.com/redis/rueidis/rueidisotel` | OpenTelemetry tracing + metrics for rueidis |
| Redis Mock | `github.com/redis/rueidis/mock` | Mock client for unit tests (no Docker needed) |
| DB Driver | `github.com/jackc/pgx/v5` | Pure Go PostgreSQL driver, faster than lib/pq, native connection pool |
| DB Pool | `github.com/jackc/pgx/v5/pgxpool` | Concurrency-safe connection pool with health checks and lifecycle hooks |
| DB Errors | `github.com/jackc/pgx/v5/pgconn` | Low-level types: PgError (constraint violations), CommandTag |
| DB OTel | `github.com/exaring/otelpgx` | OpenTelemetry tracing for pgx queries, transactions, and batches |
| DB Mock | `github.com/pashagolub/pgxmock/v4` | Mock pgxpool.Pool for unit tests (no Docker needed) |
| Migrations | `github.com/golang-migrate/migrate/v4` | Version-controlled schema migrations |
| Testing (assertions) | `github.com/stretchr/testify` | assert (continue on fail), require (stop on fail), suite |
| Testing (mocks) | `go.uber.org/mock/gomock` | Interface mock generation + expectation-based verification |
| Testing (mockgen) | `go.uber.org/mock/mockgen` | CLI tool to generate mock implementations from interfaces |
| Testing (containers) | `github.com/testcontainers/testcontainers-go` | Real DB/Redis in integration tests |
| DI (large projects) | `github.com/google/wire` | Compile-time dependency injection |
| Live Reload | `github.com/air-verse/air` | Watches file changes, rebuilds and restarts automatically via `make run/live` |
| Static Analysis | `honnef.co/go/tools/cmd/staticcheck` | Advanced Go linter, runs in `make audit` |
| Vuln Scanning | `golang.org/x/vuln/cmd/govulncheck` | Checks dependencies against Go vulnerability database |
| Dep Upgrades | `github.com/oligot/go-mod-upgrade` | Interactive listing of upgradeable direct dependencies |

---

### HTTP Framework: GoFiber v3

GoFiber v3 is the recommended HTTP framework. It is built on `fasthttp`, provides an Express-like API, and supports Go generics for type-safe request handling.

**Key change from v2**: `Ctx` is now an **interface** (not a pointer), and implements `context.Context` directly.

```go
// File: internal/adapter/inbound/http/handler/order.go
package handler

import (
	"github.com/gofiber/fiber/v3"

	"{module}/internal/application"
	"{module}/internal/application/core"
	"{module}/internal/application/orderapp"
)

type OrderHandler struct {
	app *application.Application
}

func NewOrderHandler(app *application.Application) *OrderHandler {
	return &OrderHandler{app: app}
}

// Create handles POST /orders.
func (h *OrderHandler) Create(c fiber.Ctx) error {
	var req createOrderRequest
	if err := c.Bind().Body(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid request body")
	}

	cmd := orderapp.CreateOrderCommand{
		CustomerID: req.CustomerID,
		Items:      toCommandItems(req.Items),
	}

	id, err := h.app.Commands.CreateOrder.Handle(c.Context(), cmd)
	if err != nil {
		return mapAppError(err)
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{"id": id})
}

// Get handles GET /orders/:id.
func (h *OrderHandler) Get(c fiber.Ctx) error {
	// Type-safe param extraction (Go generics)
	id := fiber.Params[string](c, "id")

	dto, err := h.app.Queries.GetOrder.Handle(c.Context(), orderapp.GetOrderQuery{OrderID: id})
	if err != nil {
		return mapAppError(err)
	}

	return c.JSON(dto)
}

// List handles GET /orders?page=1&size=20.
func (h *OrderHandler) List(c fiber.Ctx) error {
	page := fiber.Query[int](c, "page", 1)
	size := fiber.Query[int](c, "size", 20)

	// ...use page, size...
	return c.JSON(results)
}

func mapAppError(err error) error {
	var appErr *core.AppError
	if errors.As(err, &appErr) {
		return fiber.NewError(appErr.StatusCode(), appErr.Message)
	}
	return fiber.NewError(fiber.StatusInternalServerError, "internal error")
}
```

**Router setup:**

```go
// File: internal/adapter/inbound/http/router.go
package http

import (
	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
	"github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/gofiber/fiber/v3/middleware/requestid"

	"{module}/internal/adapter/inbound/http/handler"
)

func NewRouter(orderHandler *handler.OrderHandler, healthHandler *handler.HealthHandler) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler: customErrorHandler,
	})

	// Global middleware
	app.Use(recover.New())
	app.Use(requestid.New())
	app.Use(cors.New())

	// Health probes (no auth)
	app.Get("/healthz", healthHandler.Liveness)
	app.Get("/readyz", healthHandler.Readiness)

	// API routes
	api := app.Group("/api/v1")
	orders := api.Group("/orders")
	orders.Post("/", orderHandler.Create)
	orders.Get("/:id", orderHandler.Get)
	orders.Get("/", orderHandler.List)

	return app
}
```

**Fiber Bind system (replaces BodyParser, QueryParser, etc.):**

```go
// Bind from multiple sources
c.Bind().Body(&body)       // request body (JSON, XML, form)
c.Bind().URI(&params)      // URL params (struct tag: `uri:"id"`)
c.Bind().Query(&query)     // query string
c.Bind().Header(&headers)  // headers
c.Bind().Cookie(&cookies)  // cookies
```

**Type-safe generic helpers:**

```go
fiber.Params[int](c, "id", 0)           // URL param as int with default
fiber.Query[int](c, "page", 1)          // Query param as int with default
fiber.Locals[*UserClaims](c, "user")    // Type-safe locals
fiber.GetReqHeader[string](c, "X-Key")  // Type-safe header
```

**Services (typed DI for handlers):**

```go
// Register at startup
app.RegisterService(&OrderService{repo: repo})

// Access in handlers
svc := fiber.GetService[*OrderService](c)
```

**RULES:**
- Use GoFiber v3 for new projects. Stdlib `net/http` remains valid for simple services or library code.
- `c.Context()` returns `context.Context` — pass to application/domain layer.
- Use `fiber.Params[T]`, `fiber.Query[T]` generics instead of manual `strconv` parsing.
- Use `c.Bind().Body()` instead of manual JSON decoding.
- Map application errors to Fiber errors in a central function.
- Register middleware via `app.Use()`, group routes via `app.Group()`.

---

### Configuration: Viper

Use Viper for multi-source configuration with environment variable overrides and hot-reload.

```go
// File: internal/infrastructure/config/config.go
package config

import (
	"fmt"
	"strings"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Redis    RedisConfig    `mapstructure:"redis"`
	Log      LogConfig      `mapstructure:"log"`
	Telemetry TelemetryConfig `mapstructure:"telemetry"`
}

type ServerConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	ReadTimeout     time.Duration `mapstructure:"read_timeout"`
	WriteTimeout    time.Duration `mapstructure:"write_timeout"`
	ShutdownTimeout time.Duration `mapstructure:"shutdown_timeout"`
}

type DatabaseConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	Name     string `mapstructure:"name"`
	SSLMode  string `mapstructure:"ssl_mode"`
	MaxConns int    `mapstructure:"max_conns"`
}

func (c DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.Name, c.SSLMode,
	)
}

type RedisConfig struct {
	Addr     string `mapstructure:"addr"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
}

type LogConfig struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"` // "json" or "console"
}

type TelemetryConfig struct {
	Enabled      bool   `mapstructure:"enabled"`
	OTLPEndpoint string `mapstructure:"otlp_endpoint"`
	ServiceName  string `mapstructure:"service_name"`
}

// Load reads config from file + environment variables.
func Load(path string) (Config, error) {
	v := viper.New()

	// Defaults
	v.SetDefault("server.host", "0.0.0.0")
	v.SetDefault("server.port", 8080)
	v.SetDefault("server.read_timeout", "5s")
	v.SetDefault("server.write_timeout", "10s")
	v.SetDefault("server.shutdown_timeout", "30s")
	v.SetDefault("database.port", 5432)
	v.SetDefault("database.ssl_mode", "disable")
	v.SetDefault("database.max_conns", 25)
	v.SetDefault("log.level", "info")
	v.SetDefault("log.format", "json")
	v.SetDefault("telemetry.enabled", false)

	// Config file
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath(path)
	v.AddConfigPath(".")
	v.AddConfigPath("./config")

	// Environment variables: APP_SERVER_PORT → server.port
	v.SetEnvPrefix("APP")
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()

	// Read config file (optional — env vars alone are fine)
	if err := v.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return Config{}, fmt.Errorf("read config: %w", err)
		}
	}

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return Config{}, fmt.Errorf("unmarshal config: %w", err)
	}

	return cfg, nil
}
```

**Config YAML example:**

```yaml
# config/config.yaml
server:
  host: 0.0.0.0
  port: 8080
  read_timeout: 5s
  write_timeout: 10s
  shutdown_timeout: 30s

database:
  host: localhost
  port: 5432
  user: postgres
  password: ""
  name: myapp
  ssl_mode: disable
  max_conns: 25

redis:
  addr: localhost:6379
  password: ""
  db: 0

log:
  level: info
  format: json

telemetry:
  enabled: true
  otlp_endpoint: localhost:4317
  service_name: myapp
```

**RULES:**
- Use a Viper **instance** (`viper.New()`), not the global singleton.
- Use `mapstructure` struct tags for unmarshaling.
- Set `SetEnvPrefix("APP")` + `AutomaticEnv()` so `APP_DATABASE_HOST` overrides `database.host`.
- Use `SetEnvKeyReplacer` to map `.` → `_` for nested keys.
- Config file is optional — the app must work with env vars alone (12-Factor).
- Never put secrets in config files. Use env vars or secret managers for `password` fields.
- For hot-reload: call `v.WatchConfig()` + `v.OnConfigChange()` after initial load.

---

### Structured Logging: Uber Zap

Zap provides zero-allocation structured logging. Use `Logger` (typed fields) on hot paths, `SugaredLogger` (printf-style) for convenience elsewhere.

```go
// File: internal/infrastructure/logger/logger.go
package logger

import (
	"fmt"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"

	"{module}/internal/infrastructure/config"
)

// New creates a Zap logger from config.
func New(cfg config.LogConfig) (*zap.Logger, error) {
	var zapCfg zap.Config

	switch cfg.Format {
	case "console":
		zapCfg = zap.NewDevelopmentConfig()
	default:
		zapCfg = zap.NewProductionConfig()
	}

	level, err := zapcore.ParseLevel(cfg.Level)
	if err != nil {
		return nil, fmt.Errorf("parse log level: %w", err)
	}
	zapCfg.Level = zap.NewAtomicLevelAt(level)

	logger, err := zapCfg.Build()
	if err != nil {
		return nil, fmt.Errorf("build logger: %w", err)
	}

	return logger, nil
}
```

**Usage patterns:**

```go
// Logger (zero-allocation, typed fields) — use in hot paths
logger.Info("order created",
	zap.String("order_id", id),
	zap.String("customer_id", customerID),
	zap.Int("item_count", len(items)),
	zap.Duration("latency", elapsed),
)

logger.Error("save failed",
	zap.String("order_id", id),
	zap.Error(err), // key is always "error"
)

// Child logger with context (adds fields to all subsequent logs)
reqLogger := logger.With(
	zap.String("request_id", requestID),
	zap.String("method", r.Method),
	zap.String("path", r.URL.Path),
)

// SugaredLogger (printf-style) — use for convenience
sugar := logger.Sugar()
sugar.Infow("order created",
	"order_id", id,
	"customer_id", customerID,
)
sugar.Infof("processed %d orders in %v", count, elapsed)
```

**Field types (prefer typed over `zap.Any`):**

| Field | Usage |
|-------|-------|
| `zap.String("k", v)` | String values |
| `zap.Int("k", v)` | Integers |
| `zap.Float64("k", v)` | Floats |
| `zap.Bool("k", v)` | Booleans |
| `zap.Duration("k", v)` | `time.Duration` |
| `zap.Time("k", v)` | `time.Time` |
| `zap.Error(err)` | Error (key = "error") |
| `zap.Stringer("k", v)` | Any `fmt.Stringer` |
| `zap.Namespace("ns")` | Nest subsequent fields |
| `zap.Stack("k")` | Stack trace |

**RULES:**
- Always `defer logger.Sync()` in `main()` to flush buffered entries.
- Use `zap.NewProduction()` config for production (JSON, info level, sampling enabled).
- Use `zap.NewDevelopment()` for local dev (console, debug level, stacktraces on warn+).
- Use `Logger` (not `SugaredLogger`) in performance-critical code (adapters, middleware).
- Use typed field constructors (`zap.String`, `zap.Int`). Avoid `zap.Any` (uses reflection).
- Create child loggers with `logger.With(...)` for request-scoped context.
- Use `AtomicLevel` for runtime log level changes without restart.
- Sampling is enabled by default in production config — keeps log volume manageable.

---

### Observability: OpenTelemetry

OpenTelemetry (OTel) provides vendor-neutral tracing, metrics, and log correlation. Set up all three providers at startup, shut them down on exit.

**SDK Bootstrap:**

```go
// File: internal/infrastructure/telemetry/otel.go
package telemetry

import (
	"context"
	"errors"
	"fmt"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/prometheus"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"

	"{module}/internal/infrastructure/config"
)

// Setup initializes OTel providers. Returns a shutdown function.
func Setup(ctx context.Context, cfg config.TelemetryConfig) (func(context.Context) error, error) {
	if !cfg.Enabled {
		return func(context.Context) error { return nil }, nil
	}

	var shutdowns []func(context.Context) error
	shutdown := func(ctx context.Context) error {
		var errs []error
		for _, fn := range shutdowns {
			errs = append(errs, fn(ctx))
		}
		return errors.Join(errs...)
	}

	// Resource (identifies this service)
	res, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName(cfg.ServiceName),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("create resource: %w", err)
	}

	// Propagator (W3C TraceContext + Baggage)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	// Trace provider
	traceExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(cfg.OTLPEndpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("create trace exporter: %w", err)
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	shutdowns = append(shutdowns, tp.Shutdown)

	// Metric provider (Prometheus pull-based)
	promExporter, err := prometheus.New()
	if err != nil {
		return nil, fmt.Errorf("create prometheus exporter: %w", err)
	}
	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(promExporter),
		sdkmetric.WithResource(res),
	)
	otel.SetMeterProvider(mp)
	shutdowns = append(shutdowns, mp.Shutdown)

	return shutdown, nil
}
```

**Traces — creating spans:**

```go
import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

var tracer = otel.Tracer("myapp/orderapp")

func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) (string, error) {
	ctx, span := tracer.Start(ctx, "CreateOrder")
	defer span.End()

	span.SetAttributes(
		attribute.String("customer_id", cmd.CustomerID),
		attribute.Int("item_count", len(cmd.Items)),
	)

	id, err := h.doCreate(ctx, cmd)
	if err != nil {
		span.SetStatus(codes.Error, "create order failed")
		span.RecordError(err)
		return "", err
	}

	span.SetAttributes(attribute.String("order_id", id))
	return id, nil
}
```

**Metrics — counters and histograms:**

```go
import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

var meter = otel.Meter("myapp/http")

var (
	requestCount, _    = meter.Int64Counter("http.server.request_count",
		metric.WithDescription("Total HTTP requests"),
		metric.WithUnit("{request}"))
	requestDuration, _ = meter.Float64Histogram("http.server.duration",
		metric.WithDescription("HTTP request duration"),
		metric.WithUnit("s"))
)

// In middleware:
requestCount.Add(ctx, 1, metric.WithAttributes(
	attribute.String("method", method),
	attribute.Int("status", status),
))
requestDuration.Record(ctx, elapsed.Seconds(), metric.WithAttributes(
	attribute.String("method", method),
	attribute.String("route", route),
))
```

**HTTP middleware integration (Fiber):**

```go
import "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

// For stdlib net/http:
handler := otelhttp.NewHandler(mux, "server")

// For Fiber — use the Fiber OTel middleware:
import "github.com/gofiber/contrib/otelfiber/v3"
app.Use(otelfiber.Middleware())
```

**gRPC interceptor integration:**

```go
import "go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"

// Server
server := grpc.NewServer(grpc.StatsHandler(otelgrpc.NewServerHandler()))

// Client
conn, _ := grpc.Dial(addr, grpc.WithStatsHandler(otelgrpc.NewClientHandler()))
```

**RULES:**
- Initialize all providers in a single `telemetry.Setup()` function. Return a unified `shutdown` function.
- Always call `shutdown(ctx)` before process exit — flushes pending spans/metrics.
- Use `WithBatcher` (not `WithSimpleSpanProcessor`) in production for trace batching.
- Set `service.name` in the Resource — required for backend identification.
- Register `TraceContext` + `Baggage` propagators for cross-service trace correlation.
- Pass `ctx` through all layers — spans are nested by context, not manual parent references.
- Record errors with both `span.RecordError(err)` AND `span.SetStatus(codes.Error, msg)`.
- Use semantic conventions (`semconv` package) for attribute names.
- Library code imports only the OTel API (`go.opentelemetry.io/otel`), never the SDK.
- Application code configures the SDK in `cmd/` or `infrastructure/telemetry/`.

---

### High-Performance JSON: goccy/go-json

Drop-in replacement for `encoding/json` with 2-3x faster encoding/decoding. Zero code changes beyond the import.

**Migration:**

```go
// Before
import "encoding/json"

// After
import json "github.com/goccy/go-json"
```

All existing code (`json.Marshal`, `json.Unmarshal`, `json.NewEncoder`, `json.NewDecoder`) works identically.

**When to use:**
- API servers where JSON serialization is a bottleneck.
- High-throughput data pipelines.
- Any service handling >1,000 req/s where allocation reduction matters.

**When to stick with `encoding/json`:**
- Zero external dependencies is a hard requirement.
- You're writing a public library (minimize transitive deps).

**RULES:**
- Use `goccy/go-json` as the default JSON package in application code.
- Use an import alias (`import json "github.com/goccy/go-json"`) so existing code requires no changes.
- In Fiber: Fiber v3 already uses a fast JSON encoder internally. Use `go-json` for manual marshaling in application/domain layers.

---

### PostgreSQL: pgx

`github.com/jackc/pgx/v5` is the required PostgreSQL driver. Pure Go, faster than `lib/pq`, with native connection pooling, automatic statement caching, and PostgreSQL-specific features (LISTEN/NOTIFY, COPY, batch queries).

**Installation:**

```bash
go get github.com/jackc/pgx/v5
```

#### Connection Pool Setup

Always use `pgxpool.Pool` for application code — it is concurrency-safe and manages connection lifecycle automatically.

```go
import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPool creates a configured pgx connection pool.
func NewPool(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse pool config: %w", err)
	}

	// Pool tuning
	config.MaxConns = 25                          // max open connections
	config.MinConns = 5                           // keep warm connections
	config.MaxConnLifetime = 1 * time.Hour        // recycle connections
	config.MaxConnIdleTime = 30 * time.Minute     // close idle connections
	config.HealthCheckPeriod = 1 * time.Minute    // background health checks

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}

	return pool, nil
}
```

**DSN format:** `postgres://user:password@host:5432/dbname?sslmode=disable&pool_max_conns=25`

Pool-specific parameters can also be set in the DSN: `pool_max_conns`, `pool_min_conns`, `pool_max_conn_lifetime`, `pool_max_conn_idle_time`, `pool_health_check_period`.

#### Connection Lifecycle Hooks

```go
config.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
	// Run per-connection setup (e.g., SET search_path, register custom types)
	_, err := conn.Exec(ctx, "SET timezone = 'UTC'")
	return err
}

config.BeforeClose = func(conn *pgx.Conn) {
	// Cleanup before connection is destroyed
}
```

#### Query Methods

pgx uses context as the first positional argument — no `ExecContext`/`QueryContext` suffixes.

```go
// Exec — no result rows (INSERT/UPDATE/DELETE)
tag, err := pool.Exec(ctx, "DELETE FROM orders WHERE id = $1", orderID)
if tag.RowsAffected() == 0 {
	return order.ErrNotFound
}

// QueryRow — single row
var name string
err := pool.QueryRow(ctx, "SELECT name FROM users WHERE id = $1", id).Scan(&name)

// Query — multiple rows (manual scan)
rows, err := pool.Query(ctx, "SELECT id, name FROM users WHERE active = $1", true)
if err != nil {
	return nil, err
}
defer rows.Close()

for rows.Next() {
	var id int64
	var name string
	if err := rows.Scan(&id, &name); err != nil {
		return nil, err
	}
	// process row
}
if err := rows.Err(); err != nil {
	return nil, err
}
```

#### Row Collection with Generics

pgx provides generic helpers that eliminate manual scan loops.

```go
import "github.com/jackc/pgx/v5"

// Define a struct with db tags matching column names
type UserRow struct {
	ID    int64  `db:"id"`
	Name  string `db:"name"`
	Email string `db:"email"`
}

// CollectRows — collect all rows into a slice
rows, _ := pool.Query(ctx, "SELECT id, name, email FROM users")
users, err := pgx.CollectRows(rows, pgx.RowToStructByName[UserRow])

// CollectOneRow — exactly one row (returns pgx.ErrNoRows if none)
rows, _ = pool.Query(ctx, "SELECT id, name, email FROM users WHERE id = $1", id)
user, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[UserRow])

// CollectExactlyOneRow — exactly one row (returns pgx.ErrTooManyRows if >1)
rows, _ = pool.Query(ctx, "SELECT id, name, email FROM users WHERE email = $1", email)
user, err = pgx.CollectExactlyOneRow(rows, pgx.RowToStructByName[UserRow])

// RowTo — scalar values
rows, _ = pool.Query(ctx, "SELECT id FROM users WHERE active = true")
ids, err := pgx.CollectRows(rows, pgx.RowTo[int64])

// RowToAddrOf — pointer results
rows, _ = pool.Query(ctx, "SELECT id FROM users")
idPtrs, err := pgx.CollectRows(rows, pgx.RowToAddrOf[int64])
```

**RowTo functions:**
| Function | Use |
|----------|-----|
| `pgx.RowTo[T]` | Single scalar column |
| `pgx.RowToStructByPos[T]` | Struct by column position |
| `pgx.RowToStructByName[T]` | Struct by column name (uses `db` tag) |
| `pgx.RowToStructByNameLax[T]` | Struct by name, ignores extra columns |
| `pgx.RowToAddrOf[T]` | Returns `*T` instead of `T` |
| `pgx.RowToMap` | Returns `map[string]any` |

#### Named Arguments

```go
rows, err := pool.Query(ctx,
	"SELECT * FROM orders WHERE customer_id = @customer AND status = @status",
	pgx.NamedArgs{"customer": customerID, "status": "active"},
)
```

#### Transactions

```go
// Manual transaction
tx, err := pool.Begin(ctx)
if err != nil {
	return err
}
defer tx.Rollback(ctx) // no-op after Commit

_, err = tx.Exec(ctx, "INSERT INTO orders (id, status) VALUES ($1, $2)", id, "pending")
if err != nil {
	return fmt.Errorf("insert order: %w", err)
}

if err := tx.Commit(ctx); err != nil {
	return fmt.Errorf("commit: %w", err)
}
```

```go
// BeginFunc — auto commit on nil return, rollback on error (preferred)
err := pgx.BeginFunc(ctx, pool, func(tx pgx.Tx) error {
	_, err := tx.Exec(ctx, "INSERT INTO orders (id) VALUES ($1)", id)
	if err != nil {
		return err // triggers rollback
	}
	_, err = tx.Exec(ctx, "INSERT INTO order_items (order_id, product_id) VALUES ($1, $2)", id, productID)
	return err
})
```

```go
// Transaction with isolation level
err := pgx.BeginTxFunc(ctx, pool, pgx.TxOptions{
	Isolation: pgx.Serializable,
	AccessMode: pgx.ReadWrite,
}, func(tx pgx.Tx) error {
	// serializable transaction body
	return nil
})
```

**Nested transactions** use savepoints automatically:

```go
err := pgx.BeginFunc(ctx, pool, func(tx pgx.Tx) error {
	// outer transaction
	return pgx.BeginFunc(ctx, tx, func(nested pgx.Tx) error {
		// savepoint — rollback here doesn't rollback outer
		return nil
	})
})
```

#### Batch Operations

Send multiple queries in a single network round-trip.

```go
batch := &pgx.Batch{}

batch.Queue("INSERT INTO orders (id, status) VALUES ($1, $2)", id1, "pending")
batch.Queue("INSERT INTO orders (id, status) VALUES ($1, $2)", id2, "pending")
batch.Queue("SELECT count(*) FROM orders").QueryRow(func(row pgx.Row) error {
	var count int64
	return row.Scan(&count)
})

err := pool.SendBatch(ctx, batch).Close()
```

#### COPY Protocol (Bulk Insert)

Orders of magnitude faster than individual INSERTs for large datasets.

```go
rows := [][]any{
	{uuid.New(), "customer-1", "pending", int64(1500), "USD", time.Now(), time.Now()},
	{uuid.New(), "customer-2", "pending", int64(2500), "USD", time.Now(), time.Now()},
}

count, err := pool.CopyFrom(
	ctx,
	pgx.Identifier{"orders"},
	[]string{"id", "customer_id", "status", "total_cents", "currency", "created_at", "updated_at"},
	pgx.CopyFromRows(rows),
)
```

For typed slices, use `CopyFromSlice`:

```go
count, err := pool.CopyFrom(ctx, pgx.Identifier{"orders"}, columns,
	pgx.CopyFromSlice(len(orders), func(i int) ([]any, error) {
		o := orders[i]
		return []any{o.ID, o.CustomerID, o.Status, o.Total, o.Currency, o.CreatedAt, o.UpdatedAt}, nil
	}),
)
```

#### LISTEN/NOTIFY

```go
conn, err := pool.Acquire(ctx)
if err != nil {
	return err
}
defer conn.Release()

_, err = conn.Exec(ctx, "LISTEN order_events")
if err != nil {
	return err
}

for {
	notification, err := conn.Conn().WaitForNotification(ctx)
	if err != nil {
		return err
	}
	fmt.Printf("channel: %s, payload: %s\n", notification.Channel, notification.Payload)
}
```

#### Error Handling

```go
import (
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// No rows found
if errors.Is(err, pgx.ErrNoRows) {
	return nil, order.ErrNotFound
}

// PostgreSQL-specific errors (constraint violations, etc.)
var pgErr *pgconn.PgError
if errors.As(err, &pgErr) {
	switch pgErr.Code {
	case "23505": // unique_violation
		return order.ErrDuplicateID
	case "23503": // foreign_key_violation
		return order.ErrInvalidReference
	}
}

// Check rows affected
tag, err := pool.Exec(ctx, "UPDATE orders SET status = $1 WHERE id = $2", status, id)
if err != nil {
	return err
}
if tag.RowsAffected() == 0 {
	return order.ErrNotFound
}
```

**Common PostgreSQL error codes:**
| Code | Name | Typical cause |
|------|------|---------------|
| `23505` | `unique_violation` | Duplicate primary key or unique constraint |
| `23503` | `foreign_key_violation` | Referenced row doesn't exist |
| `23502` | `not_null_violation` | NULL in a NOT NULL column |
| `23514` | `check_violation` | CHECK constraint failed |
| `40001` | `serialization_failure` | Serializable transaction conflict (retry) |
| `57014` | `query_canceled` | Context cancelled or statement timeout |

Use `github.com/jackc/pgerrcode` for named constants instead of raw strings.

#### OpenTelemetry Integration

```go
import "github.com/exaring/otelpgx"

config, _ := pgxpool.ParseConfig(databaseURL)
config.ConnConfig.Tracer = otelpgx.NewTracer()

pool, err := pgxpool.NewWithConfig(ctx, config)
```

This traces all queries, transactions, batch operations, and COPY commands with span attributes for SQL text, parameters, and row counts.

#### Unit Testing with pgxmock

Mock the pool interface without a real database.

```go
import (
	"testing"

	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/require"
)

func TestOrderRepo_FindByID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	expectedRows := pgxmock.NewRows([]string{"id", "customer_id", "status", "total_cents", "currency", "created_at", "updated_at"}).
		AddRow("order-1", "cust-1", "pending", int64(1500), "USD", time.Now(), time.Now())

	mock.ExpectQuery(`SELECT .+ FROM orders WHERE id = \$1`).
		WithArgs("order-1").
		WillReturnRows(expectedRows)

	// pgxmock.NewPool() returns pgxmock.PgxPoolIface which matches pgxpool.Pool methods.
	// Use an interface in your repository to accept both real pool and mock.
	repo := persistence.NewPostgresOrderRepo(mock)
	order, err := repo.FindByID(context.Background(), orderID)

	require.NoError(t, err)
	require.Equal(t, "order-1", order.ID().String())
	require.NoError(t, mock.ExpectationsWereMet())
}
```

**Pool interface for testability:**

```go
// File: internal/adapter/outbound/persistence/db.go
package persistence

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// DBTX abstracts pgxpool.Pool and pgxmock for testing.
type DBTX interface {
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
	Begin(ctx context.Context) (pgx.Tx, error)
}
```

Use `DBTX` as the repository dependency type. Both `*pgxpool.Pool` and `pgxmock.PgxPoolIface` satisfy it.

**RULES:**
- Always use `pgxpool.Pool` for application code — never raw `pgx.Conn` (it is not concurrency-safe).
- Use `pgx.BeginFunc` / `pgx.BeginTxFunc` instead of manual Begin/Commit/Rollback to avoid forgotten rollbacks.
- Use `pgx.CollectRows` with `RowToStructByName` instead of manual scan loops — it's idiomatic and less error-prone.
- Use `pgconn.PgError` to handle constraint violations and map them to domain errors.
- Use `CopyFrom` for bulk inserts (>100 rows) — it uses the PostgreSQL COPY protocol and is 10-100x faster than batched INSERTs.
- Define a `DBTX` interface in the persistence package to decouple from `pgxpool.Pool` for unit testing with `pgxmock`.
- Never import `database/sql` or `github.com/lib/pq` — pgx is the only PostgreSQL driver.
- Pool configuration: set `MaxConns` based on `max_connections` in PostgreSQL (leave room for other clients and superuser connections).
- Always `defer pool.Close()` in main. `pool.Close()` takes no arguments.
- Use `pgx.NamedArgs` for queries with many parameters to improve readability.
- Use `otelpgx` tracer for OpenTelemetry integration — set it on `ConnConfig.Tracer` before creating the pool.

---

### Redis: rueidis

`github.com/redis/rueidis` is the recommended Redis client. High-performance with auto pipelining, server-assisted client-side caching, and support for standalone, sentinel, and cluster topologies.

**Installation:**

```bash
go get github.com/redis/rueidis
```

#### Client Creation

```go
// File: internal/infrastructure/redis/client.go
package redis

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/rueidis"

	"{module}/internal/infrastructure/config"
)

// NewClient creates a rueidis client from config.
func NewClient(cfg config.RedisConfig) (rueidis.Client, error) {
	client, err := rueidis.NewClient(rueidis.ClientOption{
		InitAddress: []string{cfg.Addr},
		Password:    cfg.Password,
		SelectDB:    cfg.DB,

		// Timeouts
		Dialer:       net.Dialer{Timeout: 5 * time.Second},
		ConnWriteTimeout: 3 * time.Second,
	})
	if err != nil {
		return nil, fmt.Errorf("create redis client: %w", err)
	}

	// Health check
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Do(ctx, client.B().Ping().Build()).Error(); err != nil {
		client.Close()
		return nil, fmt.Errorf("ping redis: %w", err)
	}

	return client, nil
}
```

**Client topologies — choose based on workload:**

```go
// Standalone (single node)
client, err := rueidis.NewClient(rueidis.ClientOption{
	InitAddress: []string{"127.0.0.1:6379"},
})

// Sentinel (automatic failover)
client, err := rueidis.NewClient(rueidis.ClientOption{
	InitAddress: []string{":26379", ":26380", ":26381"},
	Sentinel: rueidis.SentinelOption{
		MasterSet: "mymaster",
	},
})

// Cluster (horizontal scaling — auto-detected from InitAddress)
client, err := rueidis.NewClient(rueidis.ClientOption{
	InitAddress: []string{":7000", ":7001", ":7002"},
})
```

#### Command Builder

All commands use the type-safe builder pattern via `client.B()`. IDE autocomplete guides you through every Redis command.

```go
ctx := context.Background()

// SET with NX option
err := client.Do(ctx, client.B().Set().Key("key").Value("val").Nx().Build()).Error()

// GET
val, err := client.Do(ctx, client.B().Get().Key("key").Build()).ToString()

// HGETALL
hm, err := client.Do(ctx, client.B().Hgetall().Key("myhash").Build()).AsStrMap()

// HMGET
arr, err := client.Do(ctx, client.B().Hmget().Key("myhash").Field("f1", "f2").Build()).ToArray()

// DEL
err = client.Do(ctx, client.B().Del().Key("key1", "key2").Build()).Error()

// EXPIRE
err = client.Do(ctx, client.B().Expire().Key("key").Seconds(300).Build()).Error()
```

**Pin commands for reuse** (avoids allocations in hot paths):

```go
cmd := client.B().Get().Key("hot-key").Build().Pin()
// Safe to reuse cmd across goroutines
val, err := client.Do(ctx, cmd).ToString()
```

#### Cache Repository Implementation

```go
// File: internal/adapter/outbound/persistence/order_cache.go
package persistence

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/rueidis"
	json "github.com/goccy/go-json"

	"{module}/internal/domain/order"
)

// RedisOrderCache implements a cache layer for orders using rueidis.
type RedisOrderCache struct {
	client rueidis.Client
	ttl    time.Duration
}

func NewRedisOrderCache(client rueidis.Client, ttl time.Duration) *RedisOrderCache {
	return &RedisOrderCache{client: client, ttl: ttl}
}

func (c *RedisOrderCache) Get(ctx context.Context, id order.OrderID) (*order.Order, error) {
	resp := c.client.Do(ctx, c.client.B().Get().Key(c.key(id)).Build())
	if err := resp.Error(); rueidis.IsRedisNil(err) {
		return nil, order.ErrNotFound
	} else if err != nil {
		return nil, fmt.Errorf("redis get order: %w", err)
	}

	data, _ := resp.AsBytes()
	var cached cachedOrder
	if err := json.Unmarshal(data, &cached); err != nil {
		return nil, fmt.Errorf("unmarshal cached order: %w", err)
	}

	return cached.toDomain(), nil
}

func (c *RedisOrderCache) Set(ctx context.Context, o *order.Order) error {
	cached := fromDomain(o)
	data, err := json.Marshal(cached)
	if err != nil {
		return fmt.Errorf("marshal order: %w", err)
	}

	cmd := c.client.B().Set().Key(c.key(o.ID())).Value(string(data)).Ex(c.ttl).Build()
	if err := c.client.Do(ctx, cmd).Error(); err != nil {
		return fmt.Errorf("redis set order: %w", err)
	}
	return nil
}

func (c *RedisOrderCache) Invalidate(ctx context.Context, id order.OrderID) error {
	return c.client.Do(ctx, c.client.B().Del().Key(c.key(id)).Build()).Error()
}

func (c *RedisOrderCache) key(id order.OrderID) string {
	return fmt.Sprintf("order:%s", id.String())
}

// cachedOrder is the serialization format for Redis (not a domain type).
type cachedOrder struct {
	ID         string `json:"id"`
	CustomerID string `json:"customer_id"`
	Status     string `json:"status"`
	TotalCents int64  `json:"total_cents"`
	Currency   string `json:"currency"`
}

func fromDomain(o *order.Order) cachedOrder {
	return cachedOrder{
		ID:         o.ID().String(),
		CustomerID: o.Customer().String(),
		Status:     o.Status().String(),
		TotalCents: o.Total().Amount(),
		Currency:   o.Total().Currency(),
	}
}

func (c cachedOrder) toDomain() *order.Order {
	id, _ := order.ParseOrderID(c.ID)
	customerID, _ := order.ParseCustomerID(c.CustomerID)
	return order.Reconstitute(id, customerID, nil, parseStatus(c.Status),
		order.Money{}, time.Time{}, time.Time{})
}
```

#### Auto Pipelining

All concurrent non-blocking `Do()` calls are **automatically pipelined** — no explicit batching required. This gives ~14x throughput improvement over traditional clients.

```go
// Concurrent goroutines automatically pipeline
func BenchmarkAutoPipeline(b *testing.B, client rueidis.Client) {
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			client.Do(context.Background(), client.B().Get().Key("k").Build()).ToString()
		}
	})
}
```

**Disable auto pipelining** (opt-in per command):

```go
client, err := rueidis.NewClient(rueidis.ClientOption{
	InitAddress:          []string{"127.0.0.1:6379"},
	DisableAutoPipelining: true,
})

// Opt-in specific commands to pipelining
cmd := client.B().Get().Key("key").Build().ToPipe()
client.Do(ctx, cmd)
```

#### Manual Pipelining with DoMulti

Batch multiple commands explicitly when you need all results together.

```go
cmds := make(rueidis.Commands, 0, 10)
for i := 0; i < 10; i++ {
	cmds = append(cmds, client.B().Set().Key("key").Value("value").Build())
}

for _, resp := range client.DoMulti(ctx, cmds...) {
	if err := resp.Error(); err != nil {
		panic(err)
	}
}
```

#### Server-Assisted Client-Side Caching

Use `DoCache()` with a client-side TTL. Redis server invalidates cached entries automatically when data changes.

```go
// Single cached command
val, err := client.DoCache(ctx,
	client.B().Get().Key("config:feature-flags").Cache(),
	time.Minute,
).ToString()

// Multi-key cached commands
results := client.DoMultiCache(ctx,
	rueidis.CT(client.B().Get().Key("k1").Cache(), 1*time.Minute),
	rueidis.CT(client.B().Get().Key("k2").Cache(), 2*time.Minute),
)

// Check cache hit
resp := client.DoCache(ctx, client.B().Get().Key("k1").Cache(), time.Minute)
resp.IsCacheHit()  // true if served from local cache
resp.CacheTTL()    // remaining seconds
```

**Broadcast mode** (prefix-based caching):

```go
client, err := rueidis.NewClient(rueidis.ClientOption{
	InitAddress: []string{"127.0.0.1:6379"},
	ClientTrackingOptions: []string{
		"PREFIX", "config:", "PREFIX", "session:", "BCAST",
	},
})
```

**Disable caching** (for providers without tracking support):

```go
client, err := rueidis.NewClient(rueidis.ClientOption{
	InitAddress:  []string{"127.0.0.1:6379"},
	DisableCache: true, // DoCache falls back to Do
})
```

#### Pub/Sub

```go
// Publisher
err := client.Do(ctx, client.B().Publish().Channel("order.events").Message(payload).Build()).Error()

// Subscriber — blocking receive with callback
err = client.Receive(ctx,
	client.B().Subscribe().Channel("order.events", "order.updates").Build(),
	func(msg rueidis.PubSubMessage) {
		fmt.Println(msg.Channel, msg.Message)
		// For heavy processing, spawn a goroutine
	},
)

// Pattern subscribe
err = client.Receive(ctx,
	client.B().Psubscribe().Pattern("order.*").Build(),
	func(msg rueidis.PubSubMessage) {
		fmt.Println(msg.Pattern, msg.Channel, msg.Message)
	},
)
```

#### Streams (Event Sourcing / Message Queues)

```go
// Produce
id, err := client.Do(ctx, client.B().Xadd().Key("order-events").Id("*").
	FieldValue().FieldValue("event", "order.created").
	FieldValue("order_id", orderID).
	FieldValue("payload", string(jsonPayload)).
	Build()).ToString()

// Consumer group setup
client.Do(ctx, client.B().XgroupCreate().Key("order-events").
	Group("order-processor").Id("0").Mkstream().Build())

// Consume (blocking)
resp, err := client.Do(ctx, client.B().Xreadgroup().
	Group("order-processor").Consumer("worker-1").
	Count(10).Block(5000). // block 5 seconds (milliseconds)
	Streams().Key("order-events").Id(">").
	Build()).AsXRead()

for stream, messages := range resp {
	for _, msg := range messages {
		fmt.Println(stream, msg.ID, msg.FieldValues)
		// Acknowledge
		client.Do(ctx, client.B().Xack().Key("order-events").
			Group("order-processor").Id(msg.ID).Build())
	}
}
```

#### Distributed Locks

```go
import "github.com/redis/rueidis/rueidislock"

locker, err := rueidislock.NewLocker(rueidislock.LockerOption{
	ClientOption: rueidis.ClientOption{InitAddress: []string{"127.0.0.1:6379"}},
	KeyMajority:  1, // single-node majority
})
if err != nil {
	return fmt.Errorf("create locker: %w", err)
}
defer locker.Close()

// Acquire lock — ctx is released when lock is held
lockCtx, cancel, err := locker.WithContext(ctx, "order:123:lock")
if err != nil {
	return fmt.Errorf("acquire lock: %w", err)
}
defer cancel()

// Use lockCtx for work — if lock is lost, lockCtx is cancelled
doWork(lockCtx)
```

#### Lua Scripting

```go
var deductStock = rueidis.NewLuaScript(`
	local stock = tonumber(redis.call("GET", KEYS[1]))
	if not stock or stock < tonumber(ARGV[1]) then
		return 0
	end
	redis.call("DECRBY", KEYS[1], ARGV[1])
	return 1
`)

resp := deductStock.Exec(ctx, client, []string{"stock:product:123"}, []string{"5"})
ok, err := resp.AsInt64()
if ok == 0 {
	return errors.New("insufficient stock")
}
// Uses EVALSHA (cached), falls back to EVAL automatically
```

#### Error Handling

```go
resp := client.Do(ctx, client.B().Get().Key("key").Build())
if err := resp.Error(); rueidis.IsRedisNil(err) {
	// Key does not exist — not a failure
	return "", order.ErrNotFound
} else if err != nil {
	// Actual Redis error
	return "", fmt.Errorf("redis get: %w", err)
}

val, _ := resp.ToString()
return val, nil
```

**Context deadline handling:**

```go
ctx, cancel := context.WithTimeout(context.Background(), time.Second)
defer cancel()

// Returns early with context.DeadlineExceeded if deadline is reached
err := client.Do(ctx, client.B().Set().Key("key").Value("val").Build()).Error()
```

**Retry configuration:**

```go
client, err := rueidis.NewClient(rueidis.ClientOption{
	InitAddress:  []string{"127.0.0.1:6379"},
	DisableRetry: false,     // read-only commands auto-retry (default)
	RetryDelay:   myDelayFn, // custom retry delay function
})

// Mark write commands as retryable (for idempotent operations only)
client.Do(ctx, client.B().Set().Key("k").Value("v").Build().ToRetryable())
```

#### OpenTelemetry Integration

```go
import "github.com/redis/rueidis/rueidisotel"

// Create instrumented client directly
client, err := rueidisotel.NewClient(rueidis.ClientOption{
	InitAddress: []string{"127.0.0.1:6379"},
})

// Automatically instruments:
// - Tracing spans for every command
// - Metrics: rueidis_do_cache_miss, rueidis_do_cache_hits
```

Install: `go get github.com/redis/rueidis/rueidisotel`

#### Testing with rueidis mock

```go
import (
	"testing"

	"github.com/redis/rueidis/mock"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/mock/gomock"
)

func TestOrderCache_Get(t *testing.T) {
	t.Parallel()

	ctrl := gomock.NewController(t)
	client := mock.NewClient(ctrl)

	cache := persistence.NewRedisOrderCache(client, 5*time.Minute)

	// Mock a successful GET response
	client.EXPECT().
		B().Return(mock.NewCommandBuilder())
	client.EXPECT().
		Do(gomock.Any(), gomock.Any()).
		Return(mock.Result(mock.RedisString(`{"id":"abc","customer_id":"cust1","status":"pending","total_cents":1000,"currency":"USD"}`)))

	got, err := cache.Get(context.Background(), testOrderID)
	require.NoError(t, err)
	assert.Equal(t, testOrderID, got.ID())
}

func TestOrderCache_Get_NotFound(t *testing.T) {
	t.Parallel()

	ctrl := gomock.NewController(t)
	client := mock.NewClient(ctrl)

	cache := persistence.NewRedisOrderCache(client, 5*time.Minute)

	client.EXPECT().B().Return(mock.NewCommandBuilder())
	client.EXPECT().
		Do(gomock.Any(), gomock.Any()).
		Return(mock.Result(mock.RedisNil()))

	_, err := cache.Get(context.Background(), testOrderID)
	assert.ErrorIs(t, err, order.ErrNotFound)
}
```

#### Health Check Integration

```go
func (h *HealthHandler) Readiness(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	checks := map[string]string{"status": "ready"}
	status := http.StatusOK

	// Database check
	if err := h.pool.Ping(ctx); err != nil {
		checks["database"] = err.Error()
		status = http.StatusServiceUnavailable
	} else {
		checks["database"] = "ok"
	}

	// Redis check
	if err := h.redis.Do(ctx, h.redis.B().Ping().Build()).Error(); err != nil {
		checks["redis"] = err.Error()
		status = http.StatusServiceUnavailable
	} else {
		checks["redis"] = "ok"
	}

	if status != http.StatusOK {
		checks["status"] = "not ready"
	}
	writeJSON(w, status, checks)
}
```

**RULES:**
- Every Redis command takes `context.Context` as first parameter. Always pass request-scoped context.
- Use `rueidis.IsRedisNil(err)` to check for key-not-found — never compare with `==`.
- Auto pipelining is on by default — concurrent `Do()` calls are batched automatically. Only use `DoMulti` when you need results together.
- Use `DoCache()` with client-side TTL for read-heavy keys — server invalidates on write automatically.
- Use `client.B()` builder for all commands — never construct raw command strings.
- Pin commands (`Build().Pin()`) in hot paths to avoid `sync.Pool` allocations.
- Use `rueidislock` for distributed locks — the `WithContext` pattern auto-cancels on lock loss.
- Use `Receive()` for Pub/Sub — supports `SUBSCRIBE`, `PSUBSCRIBE`, and Redis 7.0 `SSUBSCRIBE`.
- Use `rueidis.NewLuaScript` for atomic multi-step operations — auto EVALSHA with EVAL fallback.
- Mark idempotent write commands as retryable with `Build().ToRetryable()`.
- Use `rueidisotel.NewClient()` for automatic tracing and caching metrics.
- Use `github.com/redis/rueidis/mock` for unit tests (fast, no Docker). Use testcontainers for integration tests.
- Use serialization structs (`cachedOrder`) for Redis values — never serialize domain entities directly.
- `Reconstitute()` to rebuild domain objects from cache — never `New()`.
- Invalidate cache on writes. Prefer cache-aside pattern: read from cache, miss → read from DB → set cache.

---

### Profiling & Performance (pprof)

Profile first, optimize second. Use `pprof` for CPU and memory profiling.

**HTTP-based profiling (for running servers):**

```go
// Add to cmd/main.go or a debug server:
import _ "net/http/pprof"

// Start a separate debug server (don't expose on public port)
go func() {
	http.ListenAndServe("localhost:6060", nil)
}()
```

Access profiles at:
- `http://localhost:6060/debug/pprof/profile?seconds=30` — CPU profile
- `http://localhost:6060/debug/pprof/heap` — heap memory profile
- `http://localhost:6060/debug/pprof/goroutine` — goroutine dump
- `http://localhost:6060/debug/pprof/allocs` — allocation profile

**Analyze with `go tool pprof`:**

```bash
# CPU profile (interactive)
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# Heap profile
go tool pprof http://localhost:6060/debug/pprof/heap

# Common pprof commands:
#   top20          — top 20 functions by flat CPU/memory
#   top -cum       — top by cumulative (including callees)
#   list FuncName  — annotated source for a function
#   web            — open flame graph in browser (needs graphviz)
#   web FuncName   — flame graph filtered to that function
```

**Flag-based profiling (for CLI tools / benchmarks):**

```go
var cpuprofile = flag.String("cpuprofile", "", "write cpu profile to file")

func main() {
	flag.Parse()
	if *cpuprofile != "" {
		f, _ := os.Create(*cpuprofile)
		pprof.StartCPUProfile(f)
		defer pprof.StopCPUProfile()
	}
	// ...
}
```

**Benchmark-driven profiling:**

```bash
go test -bench=BenchmarkX -cpuprofile=cpu.prof -memprofile=mem.prof
go tool pprof -http=:8080 cpu.prof    # opens web UI
```

**Hot-path optimization rules:**
- `strconv.Itoa(n)` over `fmt.Sprint(n)` — 2x faster, 1 alloc vs 2.
- Preallocate slices: `make([]T, 0, knownSize)` — avoids resizing during append.
- Preallocate maps: `make(map[K]V, knownSize)` — reduces rehashing.
- `strings.Builder` for piecemeal string construction — amortized linear vs quadratic.
- `sync.Pool` for short-lived objects in hot loops — reduces GC pressure.
- Convert `string` to `[]byte` once outside loops, not inside.
- Replace `map[Key]Value` with `[]Value` indexed by integer when keys are dense.

**RULES:**
- Never expose pprof on a public port. Use a separate `localhost` debug server.
- Profile in conditions close to production (realistic data, concurrency, load).
- Use `go tool pprof` interactive mode. `top -cum` finds the call chains consuming the most resources.
- `--inuse_objects` flag on heap profiles shows allocation count (not size) — useful for GC pressure analysis.
- Run benchmarks with `-benchmem` flag to see allocation counts.

---

### Memory Model & Concurrency Safety

Go's memory model defines when reads in one goroutine can observe writes from another. Violations cause data races — undefined behavior.

**Key happens-before rules:**

| Operation | Guarantee |
|-----------|-----------|
| `go f()` | The `go` statement happens-before `f()` begins |
| Goroutine exit | NOT synchronized — you must use explicit sync |
| `ch <- v` (send) | Synchronized-before the corresponding `<-ch` (receive) completes |
| `close(ch)` | Synchronized-before a receive that returns zero due to closure |
| Unbuffered `<-ch` | Receive synchronized-before the corresponding send completes |
| `mu.Unlock()` | Synchronized-before the next `mu.Lock()` returns |
| `once.Do(f)` | `f()` completion synchronized-before any `once.Do(f)` returns |
| Atomic operations | All atomics behave as sequentially consistent (sync/atomic) |

**Broken patterns — NEVER do these:**

```go
// BROKEN: busy-wait on non-synchronized variable
var done bool
go func() { done = true }()
for !done {} // may spin forever — compiler can cache 'done'

// BROKEN: double-checked locking without synchronization
var instance *Config
func GetConfig() *Config {
	if instance == nil {  // DATA RACE
		mu.Lock()
		if instance == nil {
			instance = loadConfig()
		}
		mu.Unlock()
	}
	return instance
}

// FIX: use sync.Once
var (
	instance *Config
	once     sync.Once
)
func GetConfig() *Config {
	once.Do(func() { instance = loadConfig() })
	return instance
}
```

**Race detector:**

```bash
go test -race ./...          # run tests with race detection
go build -race -o myapp      # build with race detection (dev/CI only)
```

**RULES:**
- Run `go test -race ./...` in CI on every commit. Zero tolerance for race reports.
- Never share mutable state between goroutines without synchronization.
- Prefer channels for communication. Use `sync.Mutex` for protecting shared data structures.
- Use `sync.Once` for lazy initialization, not double-checked locking.
- Use `sync/atomic` for simple counters and flags. Use `go.uber.org/atomic` for type-safe wrappers.
- Multi-word values (interfaces, slices, strings, maps) can be torn under races — always synchronize.

---

### GC Tuning

Go's garbage collector is concurrent and non-moving. Tune it for your workload using two knobs.

**GOGC — GC frequency:**

```
Target heap = Live heap + (Live heap + GC roots) * GOGC / 100
```

| GOGC | Effect |
|------|--------|
| `100` (default) | GC triggers when heap doubles since last collection |
| `200` | 2x more memory, ~half the GC CPU cost |
| `50` | Half the memory, ~double the GC CPU cost |
| `off` | Disable GC entirely (use with GOMEMLIMIT) |

```bash
GOGC=200 ./myapp                         # via env var
```

```go
import "runtime/debug"
debug.SetGCPercent(200)                  // via runtime API
```

**GOMEMLIMIT — memory ceiling (Go 1.19+):**

Soft limit on total Go memory usage. Essential for containerized workloads.

```bash
GOMEMLIMIT=512MiB ./myapp               # via env var
```

```go
debug.SetMemoryLimit(512 << 20)          // via runtime API (bytes)
```

**Best container pattern — maximum efficiency:**

```bash
# Container with 1GiB memory limit:
GOGC=off GOMEMLIMIT=900MiB ./myapp
# GC runs only when approaching the memory limit.
# Leave 10% headroom for non-Go memory (cgo, OS, buffers).
```

**When to use GOMEMLIMIT:**
- Containerized services with fixed memory (Kubernetes, ECS) — always.
- Leave 5-10% headroom below the container limit.
- Set `GOGC=off` + `GOMEMLIMIT` for maximum GC efficiency in dedicated containers.

**When NOT to use GOMEMLIMIT:**
- CLI tools, desktop apps (uncontrolled environments).
- When sharing memory with other processes — use a reasonable `GOGC` instead.

**Reducing allocation pressure (the most impactful optimization):**

```bash
go build -gcflags='-m' ./...             # see escape analysis decisions
go build -gcflags='-m -m' ./...          # verbose escape analysis
```

Techniques:
- Prefer value types over pointers when objects are small and don't escape.
- Use `sync.Pool` for frequently allocated/freed objects.
- Pre-size slices and maps.
- Avoid allocations in hot loops (hoist allocations out).
- Prefer contiguous memory (slices) over pointer-heavy structures (linked lists, trees).
- Use `strings.Builder` instead of `+` for string concatenation.

**Runtime diagnostics:**

```bash
GODEBUG=gctrace=1 ./myapp               # print GC trace to stderr
```

```go
import "runtime"

var m runtime.MemStats
runtime.ReadMemStats(&m)
// m.HeapAlloc — current heap usage
// m.NumGC     — total GC cycles
// m.PauseTotalNs — total GC pause time
```

```go
// runtime/metrics (Go 1.16+) — preferred for production monitoring
import "runtime/metrics"

samples := []metrics.Sample{
	{Name: "/memory/classes/total:bytes"},
	{Name: "/gc/cycles/total:gc-cycles"},
}
metrics.Read(samples)
```

**RULES:**
- Set `GOMEMLIMIT` in all containerized deployments. Leave 5-10% headroom.
- Use `GOGC=off` + `GOMEMLIMIT` in dedicated containers for minimum GC overhead.
- Profile allocations with `go tool pprof --allocs` before tuning GC knobs — reducing allocations is always more effective than tuning GOGC.
- Use `go build -gcflags='-m'` to understand escape analysis and fix unnecessary heap escapes.
- Monitor GC metrics in production via OTel observable gauges on `runtime.MemStats`.

---

## MAKEFILE

Every project MUST include a root `Makefile` that automates quality control, builds, and development workflows. The Makefile is the single entry point for all repeatable tasks — developers run `make` targets instead of remembering individual Go commands and flags.

Based on [Alex Edwards' Makefile template](https://www.alexedwards.net/blog/a-time-saving-makefile-for-your-go-projects), adapted to this architecture's conventions (95% coverage gate, integration test build tags, architecture tests).

```makefile
# File: Makefile

# ==================================================================================== #
# CONFIGURATION
# ==================================================================================== #

# Change these variables to match your project.
main_package_path = ./cmd/api
binary_name = api

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

.PHONY: no-dirty
no-dirty:
	@test -z "$$(git status --porcelain)"

# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## tidy: tidy modfiles and format .go files
.PHONY: tidy
tidy:
	go mod tidy -v
	go fmt ./...

## audit: run quality control checks
.PHONY: audit
audit: test
	go mod tidy -diff
	go mod verify
	test -z "$$(gofmt -l .)"
	go vet ./...
	go run honnef.co/go/tools/cmd/staticcheck@latest -checks=all,-ST1000,-U1000 ./...
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...

## test: run all unit tests
.PHONY: test
test:
	go test -v -race -buildvcs ./...

## test/cover: run all tests and enforce minimum 95% coverage
.PHONY: test/cover
test/cover:
	go test -v -race -buildvcs -coverprofile=/tmp/coverage.out ./...
	@total=$$(go tool cover -func=/tmp/coverage.out | grep total | awk '{print $$3}' | tr -d '%'); \
	if [ $$(echo "$$total < 95.0" | bc) -eq 1 ]; then \
		echo "FAIL: coverage $$total% is below 95% threshold"; exit 1; \
	else \
		echo "OK: coverage $$total%"; \
	fi
	go tool cover -html=/tmp/coverage.out

## test/integration: run integration tests (requires Docker for testcontainers)
.PHONY: test/integration
test/integration:
	go test -v -race -buildvcs -tags=integration ./...

## test/arch: run architecture dependency rule tests
.PHONY: test/arch
test/arch:
	go test -v -run TestArch ./internal/infrastructure/archtest/...

## upgradeable: list direct dependencies that have upgrades available
.PHONY: upgradeable
upgradeable:
	@go run github.com/oligot/go-mod-upgrade@latest

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## build: build the application
.PHONY: build
build:
	go build -o=/tmp/bin/${binary_name} ${main_package_path}

## run: build and run the application
.PHONY: run
run: build
	/tmp/bin/${binary_name}

## run/live: run the application with live reload on file changes
.PHONY: run/live
run/live:
	go run github.com/air-verse/air@latest \
		--build.cmd "make build" --build.bin "/tmp/bin/${binary_name}" --build.delay "100" \
		--build.exclude_dir "" \
		--build.include_ext "go,tpl,tmpl,html,css,js,ts,sql" \
		--misc.clean_on_exit "true"

# ==================================================================================== #
# OPERATIONS
# ==================================================================================== #

## push: push changes to the remote Git repository
.PHONY: push
push: confirm audit no-dirty
	git push

## production/deploy: build for linux/amd64 and deploy
.PHONY: production/deploy
production/deploy: confirm audit no-dirty
	GOOS=linux GOARCH=amd64 go build -ldflags='-s' -o=/tmp/bin/linux_amd64/${binary_name} ${main_package_path}
	# Add deployment steps here (e.g., Docker build, Kubernetes apply, rsync, etc.)
```

### Target Reference

| Target | Purpose |
|--------|---------|
| `make help` | Print all available targets with descriptions (default target) |
| `make tidy` | Run `go mod tidy` and `go fmt` to keep modules and formatting clean |
| `make audit` | Full quality gate: tests → tidy check → verify → fmt check → vet → staticcheck → govulncheck |
| `make test` | Run all unit tests with race detector enabled |
| `make test/cover` | Run tests, enforce **95% minimum coverage**, and open HTML report |
| `make test/integration` | Run integration tests using `-tags=integration` build tag (requires Docker) |
| `make test/arch` | Run architecture dependency rule enforcement tests |
| `make upgradeable` | List direct dependencies with available upgrades |
| `make build` | Compile the binary to `/tmp/bin/{binary_name}` |
| `make run` | Build and run the application |
| `make run/live` | Run with [air](https://github.com/air-verse/air) for automatic rebuild on file changes |
| `make push` | Confirm → audit → verify clean worktree → `git push` |
| `make production/deploy` | Cross-compile for linux/amd64 and deploy (customize deployment steps) |

### Key Design Decisions

- **`audit` depends on `test`**: Quality checks only run if tests pass first. This is the single target CI pipelines should call.
- **`confirm` guard**: Destructive targets (`push`, `production/deploy`) require explicit `y` confirmation.
- **`no-dirty` guard**: Prevents pushing or deploying with uncommitted changes in the worktree.
- **Coverage enforcement**: `test/cover` fails the build if total coverage drops below 95%, matching this architecture's coverage requirement.
- **Slash convention**: Related targets use `/` grouping (`test/cover`, `test/integration`, `run/live`) for discoverability via `make help`.
- **Tool pinning**: Tools like `staticcheck`, `govulncheck`, and `air` are invoked via `go run tool@version` — no global install required.

---

## DOCKERFILE

Every project MUST include a multi-stage `Dockerfile` that produces a minimal, secure production image. The Dockerfile is the single artifact that defines how the application is containerized — it compiles, tests, and packages the binary in isolated stages.

Based on [Docker's official Go guide](https://docs.docker.com/guides/golang/build-images/), adapted to this architecture's conventions (hexagonal layout, `cmd/` entry point, static binary compilation).

### Multi-Stage Dockerfile

```dockerfile
# File: Dockerfile

# syntax=docker/dockerfile:1

# ------------------------------------------------------------------------------- #
# Stage 1 — Build
# ------------------------------------------------------------------------------- #
FROM golang:1.24 AS build-stage

WORKDIR /app

# Cache dependency downloads in a separate layer.
COPY go.mod go.sum ./
RUN go mod download

# Copy the entire source tree — domain, application, adapters, infrastructure, cmd.
COPY . .

# Compile a fully static Linux binary from the project entry point.
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/api

# ------------------------------------------------------------------------------- #
# Stage 2 — Test (fails the build if any test fails)
# ------------------------------------------------------------------------------- #
FROM build-stage AS test-stage
RUN go test -v ./...

# ------------------------------------------------------------------------------- #
# Stage 3 — Release (minimal production image)
# ------------------------------------------------------------------------------- #
FROM gcr.io/distroless/base-debian12 AS release-stage

WORKDIR /

# Copy only the compiled binary from the build stage.
COPY --from=build-stage /server /server

EXPOSE 8080

# Run as non-root for security.
USER nonroot:nonroot

ENTRYPOINT ["/server"]
```

### .dockerignore

Always include a `.dockerignore` to keep the build context small and prevent secrets from leaking into images:

```
# File: .dockerignore

# Version control
.git
.gitignore

# IDE / editor
.idea/
.vscode/
*.swp
*.swo

# CI / tooling
.github/
.omc/
Makefile

# Build artifacts
bin/
coverage.out
*.test

# Documentation
*.md
LICENSE
```

### Key Conventions

| Convention | Rule |
|---|---|
| **Base image** | Use `golang:1.24` (or latest stable) for the build stage; `gcr.io/distroless/base-debian12` for the release stage |
| **Static binary** | Always compile with `CGO_ENABLED=0 GOOS=linux` — the distroless image has no C library |
| **Entry point** | Build path matches the project structure: `./cmd/api` (or the relevant `cmd/` sub-directory) |
| **Dependency caching** | Copy `go.mod` and `go.sum` first, run `go mod download`, then copy source — this leverages Docker layer caching so dependencies are only re-downloaded when module files change |
| **Test stage** | The test stage inherits from the build stage and runs `go test -v ./...` — if any test fails, `docker build` fails and no image is produced |
| **Non-root user** | The release stage uses `USER nonroot:nonroot` — never run production containers as root |
| **EXPOSE** | Document the listening port; it is informational only — runtime port mapping is still required via `-p` |
| **ENTRYPOINT vs CMD** | Use `ENTRYPOINT` for the binary (the container always runs this); use `CMD` only if default arguments are needed |

### Build & Run Commands

```bash
# Build the image (test stage runs automatically during build).
docker build --tag myapp:latest .

# Run the container, mapping host port 8080 to container port 8080.
docker run -p 8080:8080 myapp:latest

# Run with environment variables (e.g., for config).
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e DATABASE_URL="postgres://user:pass@host:5432/db" \
  myapp:latest

# Build with a specific tag.
docker build --tag myapp:v1.0.0 .

# List images to verify size (distroless release should be ~20-30 MB).
docker image ls myapp
```

### Integration with Makefile

Add Docker targets to the project Makefile:

```makefile
# ==================================================================================== #
# DOCKER
# ==================================================================================== #

## docker/build: build the Docker image
.PHONY: docker/build
docker/build:
	docker build --tag ${binary_name}:latest .

## docker/run: run the Docker container
.PHONY: docker/run
docker/run:
	docker run -p 8080:8080 ${binary_name}:latest
```

---

## PRE-COMMIT HOOKS

Every project MUST include a `.pre-commit-config.yaml` that enforces code quality gates before commits reach the repository. Pre-commit hooks catch formatting issues, lint violations, and test failures at commit time — before they enter code review or CI.

Based on [pre-commit-golang](https://github.com/tekwizely/pre-commit-golang), which provides Go-specific hooks for the [pre-commit](https://pre-commit.com/) framework.

### Installation

```bash
# Install pre-commit (macOS).
brew install pre-commit

# Install the hooks in the repo (run once after cloning).
pre-commit install
```

### Configuration

```yaml
# File: .pre-commit-config.yaml

repos:
  - repo: https://github.com/tekwizely/pre-commit-golang
    rev: v1.0.0-rc.4
    hooks:
      # ------------------------------------------------------------------ #
      # Formatting — auto-fix on commit
      # ------------------------------------------------------------------ #
      - id: go-fmt-repo
      - id: go-imports-repo

      # ------------------------------------------------------------------ #
      # Linting & Static Analysis
      # ------------------------------------------------------------------ #
      - id: go-vet-repo-mod
      - id: go-staticcheck-repo-mod
      - id: go-revive-repo-mod
      - id: go-critic
        args: [--hook:env:GO111MODULE=on]

      # ------------------------------------------------------------------ #
      # Security
      # ------------------------------------------------------------------ #
      - id: go-sec-repo-mod
      - id: go-vulncheck-repo-mod

      # ------------------------------------------------------------------ #
      # Testing
      # ------------------------------------------------------------------ #
      - id: go-test-repo-mod

      # ------------------------------------------------------------------ #
      # Module hygiene
      # ------------------------------------------------------------------ #
      - id: go-mod-tidy-repo

      # ------------------------------------------------------------------ #
      # Build verification
      # ------------------------------------------------------------------ #
      - id: go-build-repo-mod
```

### Hook Selection Rationale

| Hook | Why |
|---|---|
| `go-fmt-repo` | Enforces canonical formatting across the entire repo, not just staged files |
| `go-imports-repo` | Fixes import grouping and removes unused imports |
| `go-vet-repo-mod` | Catches suspicious constructs (printf format mismatches, unreachable code, etc.) |
| `go-staticcheck-repo-mod` | Advanced static analysis — detects deprecated APIs, unused code, and subtle bugs |
| `go-revive-repo-mod` | Configurable linter that enforces style rules beyond `go vet` |
| `go-critic` | Opinionated code reviewer — flags anti-patterns, simplifications, and performance issues |
| `go-sec-repo-mod` | Scans for common security issues (SQL injection, hardcoded credentials, etc.) |
| `go-vulncheck-repo-mod` | Checks dependencies against the Go vulnerability database |
| `go-test-repo-mod` | Runs the full test suite — prevents committing code that breaks existing tests |
| `go-mod-tidy-repo` | Ensures `go.mod` and `go.sum` stay clean — no missing or unused dependencies |
| `go-build-repo-mod` | Verifies the project compiles — catches type errors and missing imports |

### Hook Naming Conventions

The hook naming system determines scope and Go module behavior:

| Suffix | Scope | Module Mode | When to Use |
|---|---|---|---|
| _(none)_ | Changed files only | Inherits env | Quick checks on individual files |
| `-mod` | Changed files | `GO111MODULE=on` | File-level checks with module support |
| `-repo` | Entire repository | Inherits env | Repo-wide checks (formatting, builds) |
| `-repo-mod` | Entire repository | `GO111MODULE=on` | Repo-wide checks with module support |

Always prefer `-repo-mod` variants for this architecture — they ensure the entire codebase is checked with module mode enabled, not just the staged files.

### Passing Arguments and Environment Variables

```yaml
# Pass flags to the underlying tool (use '--' to separate from file list).
- id: go-staticcheck-repo-mod
  args: [-checks, 'all,-ST1000', '--']

# Set environment variables via --hook:env.
- id: go-critic
  args: [--hook:env:GO111MODULE=on, --hook:env:GOFLAGS=-mod=mod]

# Ignore specific directories.
- id: go-vet-repo-mod
  args: [--hook:ignore-dir=vendor, --hook:ignore-dir=generated]
```

### Integration with Makefile

Add a pre-commit target to the project Makefile for CI and onboarding:

```makefile
# ==================================================================================== #
# PRE-COMMIT
# ==================================================================================== #

## precommit/install: install pre-commit hooks
.PHONY: precommit/install
precommit/install:
	pre-commit install

## precommit/run: run all pre-commit hooks against all files
.PHONY: precommit/run
precommit/run:
	pre-commit run --all-files
```

---

## BRUNO API REQUESTS

Every project MUST include a `bruno/` directory at the repository root containing API request collections managed with [Bruno](https://www.usebruno.com/) — an open-source, offline-first API client that stores requests as plain-text files in version control.

Bruno replaces Postman/Insomnia with Git-friendly `.bru` files that live alongside the code. No cloud sync, no accounts — collections are reviewed, versioned, and shared through the same pull request workflow as the source code.

### Directory Structure

```
bruno/
  bruno.json                     # Collection metadata
  environments/
    local.bru                    # Local development variables
    staging.bru                  # Staging environment variables
  health/
    get-liveness.bru             # GET /healthz
    get-readiness.bru            # GET /readyz
  {aggregate}/
    create-{entity}.bru          # POST /{aggregate}
    get-{entity}-by-id.bru       # GET /{aggregate}/:id
    list-{entities}.bru          # GET /{aggregate}
    update-{entity}.bru          # PUT /{aggregate}/:id
    delete-{entity}.bru          # DELETE /{aggregate}/:id
```

### Collection Configuration

```json
// File: bruno/bruno.json
{
  "version": "1",
  "name": "my-api",
  "type": "collection",
  "ignore": ["node_modules"]
}
```

### Environment Files

```bru
// File: bruno/environments/local.bru
vars {
  baseUrl: http://localhost:8080
  authToken: dev-token-for-local-testing
}
```

```bru
// File: bruno/environments/staging.bru
vars {
  baseUrl: https://api.staging.example.com
  authToken: {{process.env.STAGING_AUTH_TOKEN}}
}
```

### Sample Requests

#### Health Check

```bru
// File: bruno/health/get-liveness.bru
meta {
  name: Get Liveness
  type: http
  seq: 1
}

get {
  url: {{baseUrl}}/healthz
}

tests {
  test("should return 200", function() {
    expect(res.status).to.equal(200);
  });
}
```

#### Create Entity (POST)

```bru
// File: bruno/{aggregate}/create-{entity}.bru
meta {
  name: Create Order
  type: http
  seq: 1
}

post {
  url: {{baseUrl}}/orders
}

headers {
  Content-Type: application/json
  Authorization: Bearer {{authToken}}
}

body:json {
  {
    "customerId": "cust-123",
    "items": [
      {
        "productId": "prod-456",
        "quantity": 2
      }
    ]
  }
}

script:post-response {
  if (res.status === 201) {
    bru.setVar("orderId", res.body.id);
  }
}

tests {
  test("should return 201 Created", function() {
    expect(res.status).to.equal(201);
  });

  test("should return order id", function() {
    expect(res.body.id).to.be.a('string');
  });
}
```

#### Get Entity by ID (GET)

```bru
// File: bruno/{aggregate}/get-{entity}-by-id.bru
meta {
  name: Get Order by ID
  type: http
  seq: 2
}

get {
  url: {{baseUrl}}/orders/:id
}

params:path {
  id: {{orderId}}
}

headers {
  Authorization: Bearer {{authToken}}
}

tests {
  test("should return 200", function() {
    expect(res.status).to.equal(200);
  });

  test("should return the correct order", function() {
    expect(res.body.id).to.equal(bru.getVar("orderId"));
  });
}
```

#### List Entities (GET with Query Params)

```bru
// File: bruno/{aggregate}/list-{entities}.bru
meta {
  name: List Orders
  type: http
  seq: 3
}

get {
  url: {{baseUrl}}/orders
}

params:query {
  page: 1
  pageSize: 20
  status: confirmed
}

headers {
  Authorization: Bearer {{authToken}}
}

tests {
  test("should return 200", function() {
    expect(res.status).to.equal(200);
  });

  test("should return an array", function() {
    expect(res.body.items).to.be.an('array');
  });
}
```

### Bruno CLI

Install and run collections from the command line for CI/CD integration:

```bash
# Install the CLI.
npm install -g @usebruno/cli

# Run all requests in the collection with the local environment.
bru run --env local

# Run a specific folder.
bru run bruno/health --env local

# Run with a JUnit report for CI.
bru run --env staging --reporter-junit results.xml

# Run only requests tagged as "smoke".
bru run --env local --tags smoke

# Stop on first failure.
bru run --env staging --bail
```

### Key Conventions

| Convention | Rule |
|---|---|
| **Directory per aggregate** | Mirror the domain structure — one folder per aggregate under `bruno/` |
| **File naming** | Use `{verb}-{entity}.bru` pattern (e.g., `create-order.bru`, `list-orders.bru`) |
| **Environment variables** | Store base URLs and tokens in environment files, never hardcode in requests |
| **Request chaining** | Use `script:post-response` with `bru.setVar()` to pass IDs between requests |
| **Inline tests** | Every request SHOULD include at least a status code assertion in the `tests` block |
| **Sequence ordering** | Use `seq` in `meta` to control execution order within a folder |
| **Secrets** | Use `{{process.env.VAR}}` for sensitive values — never commit real tokens |
| **Git integration** | The entire `bruno/` directory is committed to version control |

---

## QUICK REFERENCE: ADDING A NEW FEATURE (FULL_FEATURE)

When the user says "add feature X", execute this checklist:

1. **Domain** (`internal/domain/{aggregate}/`)
   - [ ] Define entity with unexported fields + getter methods
   - [ ] Create value objects with validation constructors
   - [ ] Define enum types starting at `iota + 1`
   - [ ] Add repository port interface (consumer-defined)
   - [ ] Define domain events (if state transitions matter)
   - [ ] Add sentinel errors (`ErrX`)
   - [ ] Add `//go:generate mockgen` directives to port interface files
   - [ ] Write domain unit tests with `testify/assert` + `testify/require`

2. **Application** (`internal/application/{aggregate}/`)
   - [ ] Create command struct (primitive types) + handler (one per file)
   - [ ] Create query struct + handler returning DTO (one per file)
   - [ ] Implement generic `CommandHandler[C, R]` / `QueryHandler[Q, R]` interfaces
   - [ ] Wrap with decorators (logging, metrics) in Application factory
   - [ ] Use `ExecuteInTransaction` for write operations
   - [ ] Define application ports if needed (mailer, storage)
   - [ ] Generate mocks: `go generate ./...`
   - [ ] Write application unit tests with gomock + testify

3. **Inbound Adapter** (`internal/adapter/inbound/http/`)
   - [ ] Add HTTP handler methods (request → converter → command → response)
   - [ ] Define request/response types with JSON tags
   - [ ] Add converter if mapping is complex
   - [ ] Register routes in router
   - [ ] Map errors via `AppError.StatusCode()` or domain error → HTTP status mapping

4. **Outbound Adapter** (`internal/adapter/outbound/`)
   - [ ] Implement repository (PostgreSQL + in-memory for tests)
   - [ ] Add compile-time interface check: `var _ Port = (*Adapter)(nil)`
   - [ ] Implement event publisher if needed
   - [ ] Subscribe event handlers to EventBus in DI wiring
   - [ ] Write integration tests with testcontainers (build tag: `integration`)

5. **Infrastructure** (`internal/infrastructure/`, `cmd/`)
   - [ ] Wire new dependencies in DI container (manual or Wire)
   - [ ] Register new handlers in Application factory (with decorators)
   - [ ] Add Viper config fields if new settings needed
   - [ ] Register new routes in Fiber router
   - [ ] Ensure health checks include new dependencies (`/readyz`)
   - [ ] Add OTel spans in use case handlers (`tracer.Start`)
   - [ ] Add OTel metrics for key operations (counters, histograms)
   - [ ] Use Zap structured logging with typed fields
   - [ ] Run all tests: `go test ./...`
   - [ ] Run race detector: `go test -race ./...`
   - [ ] Verify coverage >= 95%: `go test -coverprofile=coverage.out ./... && go tool cover -func=coverage.out`
   - [ ] Run integration tests: `go test -tags=integration ./...`
   - [ ] Run linters: `go vet ./...` + `staticcheck ./...`
   - [ ] Run arch tests: verify dependency rules pass
   - [ ] Profile if performance-sensitive: `go test -bench=. -benchmem`