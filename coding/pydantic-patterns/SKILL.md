---
name: pydantic-patterns
description: MUST USE when working with Pydantic v2 models — validators, model inheritance, discriminated unions, custom types, serialization, computed fields, and integration with FastAPI/SQLAlchemy. Covers migration from v1 and advanced patterns.
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: python
  framework: pydantic
  pattern: data-validation
---

# Pydantic v2 Patterns

> Reference skill for Pydantic v2 (latest: **2.13.4**). All examples target v2 API only.
> Pydantic v2 is a ground-up Rust-backed rewrite — do NOT mix v1 APIs.

---

## 1. Model Definition Patterns

### Basic BaseModel

```python
from datetime import datetime
from pydantic import BaseModel, Field

class User(BaseModel):
    id: int
    name: str = "Anonymous"
    email: str = Field(
        ...,  # required
        min_length=5,
        max_length=254,
        pattern=r"^[\w.-]+@[\w.-]+\.\w+$",
        description="User email address",
        examples=["user@example.com"],
    )
    signup_ts: datetime | None = None
    tags: list[str] = Field(default_factory=list)
```

### Field() Parameters Quick Reference

```python
from pydantic import Field

# Numeric constraints
price: float = Field(gt=0, le=10_000, description="Product price in USD")

# String constraints
sku: str = Field(min_length=3, max_length=20, pattern=r"^[A-Z0-9-]+$")

# Collection constraints
items: list[int] = Field(min_length=1, max_length=100)

# Aliases (for JSON keys that aren't valid Python identifiers)
class Config(BaseModel):
    api_key: str = Field(alias="api-key")
    db_url: str = Field(alias="database_url", validation_alias="DB_URL")
    output_name: str = Field(serialization_alias="outputName")  # camelCase output

# Deprecated fields
old_field: str | None = Field(default=None, deprecated=True)

# Exclude from serialization
password: str = Field(exclude=True)

# Frozen (immutable) individual field
name: str = Field(frozen=True)
```

### model_config with ConfigDict

```python
from pydantic import BaseModel, ConfigDict

class StrictUser(BaseModel):
    model_config = ConfigDict(
        strict=True,               # no type coercion
        frozen=True,               # immutable instances
        populate_by_name=True,     # allow field name AND alias
        str_strip_whitespace=True, # strip whitespace from strings
        validate_default=True,     # validate default values
        extra="forbid",            # raise error on extra fields
        use_enum_values=True,      # store enum value, not enum member
        from_attributes=True,      # ORM mode (was orm_mode in v1)
    )
    id: int
    name: str
```

---

## 2. Validators

### field_validator (before / after / wrap)

```python
from pydantic import BaseModel, field_validator

class Product(BaseModel):
    name: str
    price: float
    sku: str

    # AFTER mode (default): runs after Pydantic's own validation
    @field_validator("name")
    @classmethod
    def name_must_be_title_case(cls, v: str) -> str:
        if v != v.title():
            raise ValueError("name must be title case")
        return v

    # BEFORE mode: runs before Pydantic validation — input may be raw
    @field_validator("price", mode="before")
    @classmethod
    def parse_price_string(cls, v: object) -> float:
        if isinstance(v, str):
            return float(v.replace("$", "").replace(",", ""))
        return v  # type: ignore[return-value]

    # WRAP mode: wraps Pydantic's validator — you control the pipeline
    @field_validator("sku", mode="wrap")
    @classmethod
    def normalize_sku(cls, v: object, handler):
        if isinstance(v, str):
            v = v.upper().strip()
        return handler(v)  # call Pydantic's default validation

    # Validate multiple fields with one validator
    @field_validator("name", "sku")
    @classmethod
    def no_empty_strings(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("must not be empty")
        return v
```

### model_validator (before / after)

```python
from typing import Self
from pydantic import BaseModel, model_validator


class DateRange(BaseModel):
    start: int
    end: int

    # AFTER mode: model is already constructed, access self.*
    @model_validator(mode="after")
    def check_range(self) -> Self:
        if self.start >= self.end:
            raise ValueError("start must be before end")
        return self


class ExternalInput(BaseModel):
    raw: dict

    # BEFORE mode: receives raw input (dict), can reshape before parsing
    @model_validator(mode="before")
    @classmethod
    def flatten_nested(cls, data: dict) -> dict:
        if "payload" in data:
            return data["payload"]
        return data
```

### WRAP model_validator

```python
from pydantic import BaseModel, model_validator, ValidatorFunctionWrapHandler


class Flexible(BaseModel):
    value: int

    @model_validator(mode="wrap")
    @classmethod
    def try_parse(cls, data, handler: ValidatorFunctionWrapHandler):
        if isinstance(data, int):
            data = {"value": data}
        return handler(data)

print(Flexible.model_validate(42))  # Flexible(value=42)
```

---

## 3. Custom Types and Annotated Patterns

### Reusable Annotated Types

```python
from typing import Annotated
from pydantic import AfterValidator, BeforeValidator, Field
from pydantic import TypeAdapter


# Reusable validated type
def check_positive(v: int) -> int:
    if v <= 0:
        raise ValueError("must be positive")
    return v

PositiveInt = Annotated[int, AfterValidator(check_positive)]


# Composable: stack multiple validators and Field metadata
def strip_lower(v: str) -> str:
    return v.strip().lower()

NormalizedStr = Annotated[
    str,
    BeforeValidator(strip_lower),
    Field(min_length=1, max_length=100),
]


# TypeAdapter for standalone validation (no model needed)
adapter = TypeAdapter(list[PositiveInt])
result = adapter.validate_python([1, 2, 3])
```

### PlainValidator (full replacement)

```python
from typing import Annotated
from pydantic import PlainValidator

def parse_bool(v: object) -> bool:
    if isinstance(v, str):
        return v.lower() in ("yes", "true", "1", "on")
    return bool(v)

FlexBool = Annotated[bool, PlainValidator(parse_bool)]
```

### Custom types with __get_pydantic_core_schema__

```python
from typing import Any
from pydantic import GetCoreSchemaHandler
from pydantic_core import CoreSchema, core_schema

class Color:
    def __init__(self, value: str):
        if not value.startswith("#") or len(value) != 7:
            raise ValueError("invalid hex color")
        self.value = value

    @classmethod
    def __get_pydantic_core_schema__(
        cls, source_type: Any, handler: GetCoreSchemaHandler
    ) -> CoreSchema:
        return core_schema.no_info_plain_validator_function(
            lambda v: cls(v) if isinstance(v, str) else v,
            serialization=core_schema.to_string_ser_schema(),
        )
```

---

## 4. Serialization

### model_dump and model_dump_json

```python
from pydantic import BaseModel

class Order(BaseModel):
    id: int
    item: str
    price: float
    internal_note: str

order = Order(id=1, item="Widget", price=9.99, internal_note="rush")

order.model_dump()                        # -> dict
order.model_dump(exclude={"internal_note"})
order.model_dump(include={"id", "item"})
order.model_dump(exclude_none=True)       # skip None values
order.model_dump(exclude_unset=True)      # skip fields not explicitly set
order.model_dump(by_alias=True)           # use alias names
order.model_dump_json(indent=2)           # -> JSON str (Rust serializer, fast)
Order.model_validate_json('{"id":1,"item":"W","price":9.99,"internal_note":"r"}')
```

### Custom Serializers

```python
from datetime import datetime
from pydantic import BaseModel, field_serializer, model_serializer, SerializerFunctionWrapHandler

class Event(BaseModel):
    name: str
    timestamp: datetime

    @field_serializer("timestamp")
    def serialize_ts(self, v: datetime, _info) -> str:
        return v.isoformat()

class SecureUser(BaseModel):
    username: str
    password: str

    @model_serializer(mode="wrap")
    def redact(self, handler: SerializerFunctionWrapHandler) -> dict:
        data = handler(self)
        data.pop("password", None)
        return data
```

### PlainSerializer / WrapSerializer with Annotated

```python
from typing import Annotated
from datetime import datetime
from pydantic import PlainSerializer

EpochTimestamp = Annotated[
    datetime,
    PlainSerializer(lambda v: int(v.timestamp()), return_type=int),
]
```

---

## 5. Discriminated Unions

### Literal Discriminator (simple)

```python
from typing import Literal, Union
from pydantic import BaseModel, Field


class Cat(BaseModel):
    pet_type: Literal["cat"]
    meows: int

class Dog(BaseModel):
    pet_type: Literal["dog"]
    barks: float

class Household(BaseModel):
    pet: Union[Cat, Dog] = Field(discriminator="pet_type")

h = Household.model_validate({"pet": {"pet_type": "cat", "meows": 3}})
# Household(pet=Cat(pet_type='cat', meows=3))
```

### Custom Callable Discriminator

Use when models have **different discriminator field names** or complex logic:

```python
from typing import Annotated, Any, Literal, Union
from pydantic import BaseModel, Discriminator, Tag

class Cat(BaseModel):
    pet_type: Literal["cat"]
    age: int

class Dog(BaseModel):
    pet_kind: Literal["dog"]  # different field name!
    age: int

def pet_discriminator(v: Any) -> str:
    if isinstance(v, dict):
        return v.get("pet_type", v.get("pet_kind"))
    return getattr(v, "pet_type", getattr(v, "pet_kind", None))

class Household(BaseModel):
    pet: Annotated[
        Union[Annotated[Cat, Tag("cat")], Annotated[Dog, Tag("dog")]],
        Discriminator(pet_discriminator),
    ]
```

### Nested Discriminated Unions

```python
from typing import Annotated, Literal, Union
from pydantic import BaseModel, Field


class EmailNotification(BaseModel):
    channel: Literal["email"]
    to: str

class SMSNotification(BaseModel):
    channel: Literal["sms"]
    phone: str

class WebhookNotification(BaseModel):
    channel: Literal["webhook"]
    url: str

Notification = Annotated[
    Union[EmailNotification, SMSNotification, WebhookNotification],
    Field(discriminator="channel"),
]

class Alert(BaseModel):
    title: str
    notifications: list[Notification]
```

---

## 6. Computed Fields

```python
from pydantic import BaseModel, computed_field


class Rectangle(BaseModel):
    width: float
    height: float

    @computed_field
    @property
    def area(self) -> float:
        return self.width * self.height

    @computed_field(repr=False)  # exclude from __repr__
    @property
    def perimeter(self) -> float:
        return 2 * (self.width + self.height)

r = Rectangle(width=3, height=4)
r.area        # 12.0
r.model_dump() # {"width": 3.0, "height": 4.0, "area": 12.0, "perimeter": 14.0}
```

### Computed fields with cached_property

```python
from functools import cached_property
from pydantic import BaseModel, computed_field, ConfigDict


class ExpensiveModel(BaseModel):
    model_config = ConfigDict(ignored_types=(cached_property,))

    data: list[float]

    @computed_field
    @cached_property
    def mean(self) -> float:
        return sum(self.data) / len(self.data)
```

---

## 7. Model Inheritance and Generic Models

### Basic Inheritance

```python
from pydantic import BaseModel

class BaseUser(BaseModel):
    name: str
    email: str

class AdminUser(BaseUser):
    role: str = "admin"
    permissions: list[str] = []

# AdminUser has name, email, role, permissions
```

### Generic Models

```python
from typing import Generic, TypeVar
from pydantic import BaseModel, computed_field

T = TypeVar("T")

class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    per_page: int

    @computed_field
    @property
    def has_next(self) -> bool:
        return self.page * self.per_page < self.total

# Usage: PaginatedResponse[User](items=[...], total=50, page=1, per_page=10)
```

### Generic Models with Bounds

```python
from typing import Generic, TypeVar
from pydantic import BaseModel

T = TypeVar("T", bound=BaseModel)

class Envelope(BaseModel, Generic[T]):
    data: T
    metadata: dict[str, str] = {}
```

---

## 8. Settings Management (pydantic-settings)

> Install: `pip install pydantic-settings`

### Basic Settings

```python
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="APP_",           # reads APP_DATABASE_URL, etc.
        env_nested_delimiter="__",   # APP_DB__HOST -> db.host
        case_sensitive=False,
        extra="ignore",
    )
    debug: bool = False
    database_url: str = Field(alias="DATABASE_URL")
    redis_url: str = "redis://localhost:6379/0"
    max_connections: int = Field(default=50, ge=1, le=1000)
```

### Nested Settings

```python
from pydantic import BaseModel
from pydantic_settings import BaseSettings, SettingsConfigDict

class DatabaseConfig(BaseModel):
    host: str = "localhost"
    port: int = 5432
    name: str = "mydb"

class AppSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="APP_", env_nested_delimiter="__")
    db: DatabaseConfig = DatabaseConfig()
    # Set via: APP_DB__HOST=remotehost APP_DB__PORT=5433
```

### Multiple .env files and priority

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", ".env.local"),  # .env.local overrides .env
    )
    # Priority: init kwargs > env vars > .env.local > .env > defaults
```

---

## 9. Integration with FastAPI

### Request / Response Models

```python
from fastapi import FastAPI
from pydantic import BaseModel, Field, EmailStr

app = FastAPI()

class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8)

class UserResponse(BaseModel):
    id: int
    name: str
    email: EmailStr  # password excluded — never in response

@app.post("/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate) -> UserResponse:
    return UserResponse(id=1, name=user.name, email=user.email)
```

### Dependency Injection with Settings

```python
from functools import lru_cache
from fastapi import Depends, FastAPI
from pydantic_settings import BaseSettings

app = FastAPI()

class Settings(BaseSettings):
    database_url: str = "sqlite:///./test.db"

@lru_cache
def get_settings() -> Settings:
    return Settings()

@app.get("/info")
async def info(settings: Settings = Depends(get_settings)):
    return {"db": str(settings.database_url)}
```

### Query Parameter Models (FastAPI 0.115+)

```python
from fastapi import FastAPI, Query
from pydantic import BaseModel, Field

app = FastAPI()

class Pagination(BaseModel):
    page: int = Field(default=1, ge=1)
    per_page: int = Field(default=20, ge=1, le=100)

@app.get("/items")
async def list_items(params: Pagination = Query()):
    return {"page": params.page}
```

---

## 10. Integration with SQLAlchemy

### from_attributes (was orm_mode)

```python
from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import DeclarativeBase
from pydantic import BaseModel, ConfigDict


class Base(DeclarativeBase):
    pass


class UserORM(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String(100))
    email = Column(String(254))


class UserSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str


# Usage: convert ORM object to Pydantic model
# user_orm = session.get(UserORM, 1)
# user = UserSchema.model_validate(user_orm)
```

### Partial Updates Pattern (PATCH)

```python
from pydantic import BaseModel

class UserUpdate(BaseModel):
    name: str | None = None
    email: str | None = None

    def apply_to_orm(self, orm_obj):
        for field, value in self.model_dump(exclude_unset=True).items():
            setattr(orm_obj, field, value)
        return orm_obj
```

### Read vs Write Schemas

```python
from datetime import datetime
from pydantic import BaseModel, ConfigDict

class UserBase(BaseModel):
    name: str
    email: str

class UserCreate(UserBase):
    password: str

class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime
```

---

## 11. JSON Schema Customization

### Field-level JSON Schema

```python
from pydantic import BaseModel, Field


class Product(BaseModel):
    name: str = Field(
        title="Product Name",
        description="The display name of the product",
        examples=["Widget Pro", "Gadget X"],
        json_schema_extra={"x-frontend-widget": "text-input"},
    )
    price: float = Field(
        ge=0,
        description="Price in USD",
        json_schema_extra={"x-currency": "USD"},
    )

schema = Product.model_json_schema()
```

### Model-level JSON Schema

```python
from pydantic import BaseModel, ConfigDict

class Event(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={"examples": [{"name": "Launch Party", "attendees": 50}]},
        title="CalendarEvent",
    )
    name: str
    attendees: int

# Generate JSON Schema (OpenAPI-compatible)
Event.model_json_schema()
Event.model_json_schema(ref_template="#/$defs/{model}")
```

---

## 12. Performance Patterns

### Strict Mode (skip coercion overhead)

```python
from pydantic import BaseModel, ConfigDict


class StrictEvent(BaseModel):
    model_config = ConfigDict(strict=True)

    id: int        # "123" will FAIL, must be int
    name: str
    active: bool   # 1 will FAIL, must be bool
```

### model_validate vs __init__

```python
# model_validate is preferred for external data — runs full validation
user = User.model_validate({"id": 1, "name": "Alice"})

# model_construct skips validation — use ONLY for trusted, pre-validated data
user = User.model_construct(id=1, name="Alice")
# WARNING: no validation, no coercion, no defaults for missing fields
```

### TypeAdapter for Bulk Validation

```python
from pydantic import TypeAdapter

adapter = TypeAdapter(list[User])

# Validate a list without wrapping in a model
users = adapter.validate_python([
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"},
])

# JSON round-trip
json_bytes = adapter.dump_json(users)
users_back = adapter.validate_json(json_bytes)
```

### Avoid Recompiling Models

```python
# BAD: model rebuilt every call
def process(data: dict):
    class DynamicModel(BaseModel): ...  # schema recompiled each time!

# GOOD: define at module level
class ValueModel(BaseModel):
    value: int
```

### Forward References and model_rebuild

```python
from __future__ import annotations
from pydantic import BaseModel

class TreeNode(BaseModel):
    value: int
    children: list[TreeNode] = []

# For dynamic models, call explicitly: TreeNode.model_rebuild()
```

---

## 13. Migration from v1 to v2 — Quick Reference

| v1 (DEPRECATED)                  | v2 (USE THIS)                           |
|----------------------------------|-----------------------------------------|
| `class Config:`                  | `model_config = ConfigDict(...)`        |
| `Config.orm_mode = True`         | `ConfigDict(from_attributes=True)`      |
| `@validator("field")`            | `@field_validator("field")`             |
| `@root_validator`                | `@model_validator(mode="after")`        |
| `@root_validator(pre=True)`      | `@model_validator(mode="before")`       |
| `.dict()`                        | `.model_dump()`                         |
| `.json()`                        | `.model_dump_json()`                    |
| `.parse_obj(data)`               | `.model_validate(data)`                 |
| `.parse_raw(json_str)`           | `.model_validate_json(json_str)`        |
| `.schema()`                      | `.model_json_schema()`                  |
| `.construct()`                   | `.model_construct()`                    |
| `.copy(update={...})`            | `.model_copy(update={...})`             |
| `from pydantic import validator` | `from pydantic import field_validator`  |
| `Field(regex=...)`               | `Field(pattern=...)`                    |
| `Field(min_items=...)`           | `Field(min_length=...)`                 |
| `Field(max_items=...)`           | `Field(max_length=...)`                |
| `Optional[str]`                  | `str \| None = None`                    |
| `__fields__`                     | `model_fields`                          |
| `__validators__`                 | Removed; use `__pydantic_validator__`   |
| `update_forward_refs()`          | `model_rebuild()`                       |
| `from pydantic import v1`        | Compat shim, remove ASAP               |

### Key Behavioral Changes in v2

- `@field_validator` MUST be `@classmethod`; `model_validator(mode="after")` receives `self`, not `values`
- Strict mode is real: `int("123")` raises, not coerces
- Extra fields default is `"ignore"`, not `"forbid"`
- `.dict()` / `.json()` still work but are deprecated
- Arbitrary types need `ConfigDict(arbitrary_types_allowed=True)`

---

## 14. Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Using `class Config:` in v2 | Deprecated, may break | Use `model_config = ConfigDict(...)` |
| `@validator` / `@root_validator` | Deprecated v1 API | Use `@field_validator` / `@model_validator` |
| `.dict()` / `.json()` | Deprecated, missing features | Use `.model_dump()` / `.model_dump_json()` |
| `model_construct()` on user input | Skips ALL validation | Use `model_validate()` for external data |
| Mutable default `list` in Field | Shared across instances | Use `Field(default_factory=list)` |
| Defining models inside functions | Recompiles schema every call | Define at module level |
| `Optional[X]` without `= None` | Required field that accepts None | Always add `= None` for optional |
| `extra="allow"` everywhere | Silent bugs from typos | Use `extra="forbid"` or `extra="ignore"` |
| Ignoring `exclude_unset` in PATCH | Overwrites fields with None | Use `model_dump(exclude_unset=True)` |
| Bare `Union[A, B]` for many types | Slow, tries each in order | Use discriminated unions |
| `Any` as field type | No validation at all | Use specific types or constrained types |
| `json_schema_extra` with lambdas | Breaks JSON schema generation | Use plain dicts for `json_schema_extra` |
| Mixing v1 and v2 API in same model | Undefined behavior | Fully migrate each model |
| Not using `from_attributes` with ORM | `model_validate(orm_obj)` fails | Set `from_attributes=True` in ConfigDict |

---

## 15. Verification Checklist

Before shipping Pydantic models, verify:

- [ ] All imports are from `pydantic` v2 API (no `validator`, `root_validator`)
- [ ] `model_config = ConfigDict(...)` used instead of `class Config:`
- [ ] `Field()` uses v2 parameter names (`pattern` not `regex`, `min_length` not `min_items`)
- [ ] `.model_dump()` / `.model_dump_json()` used, not `.dict()` / `.json()`
- [ ] `.model_validate()` used, not `.parse_obj()`
- [ ] `@field_validator` decorated with `@classmethod`
- [ ] `@model_validator(mode="after")` returns `Self`, not dict
- [ ] `@model_validator(mode="before")` decorated with `@classmethod`
- [ ] Discriminated unions use `Field(discriminator=...)` or `Discriminator()`
- [ ] `from_attributes=True` set for any ORM integration
- [ ] `model_construct()` only used with trusted, pre-validated data
- [ ] `extra="forbid"` on public-facing API models
- [ ] `frozen=True` on models that should be immutable / hashable
- [ ] No mutable defaults — use `default_factory`
- [ ] `pydantic-settings` used for env/config, not hand-rolled `os.getenv()`
- [ ] JSON schema output reviewed with `Model.model_json_schema()`
- [ ] Type hints are precise (no bare `Any`, no `dict` without key/value types)
- [ ] Computed fields use `@computed_field` + `@property`, not validator hacks
- [ ] Generic models have proper `TypeVar` bounds
- [ ] Forward references resolved (use `from __future__ import annotations` or `model_rebuild()`)
