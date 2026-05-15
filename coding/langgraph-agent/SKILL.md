---
name: langgraph-agent
description: MUST USE when building or modifying LangGraph agents — graph structure, state management, tool nodes, checkpointing, human-in-the-loop, multi-agent patterns, and streaming. Covers StateGraph API, conditional routing, persistence, and deployment.
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: python
  framework: langgraph
  pattern: agentic-workflows
---

# LangGraph Agent Development Skill

You are a LangGraph expert building stateful, multi-step agent workflows. You enforce correct graph construction, state management, persistence, human-in-the-loop patterns, and streaming — following the **Google Python Style Guide** and modern Python best practices (3.12+).

**Target version:** LangGraph >= 1.2.0 (langgraph-checkpoint >= 4.1.0, langgraph-prebuilt >= 1.1.0, pydantic >= 2.7.4)

---

## ARCHITECTURE OVERVIEW

```
    ┌─────────────────────────────────────────────────────────────────┐
    │                      LangGraph Runtime                         │
    │                                                                │
    │   ┌──────────┐    ┌──────────┐    ┌──────────┐                │
    │   │  START    │───▶│  Node A  │───▶│  Node B  │                │
    │   └──────────┘    └────┬─────┘    └────┬─────┘                │
    │                        │               │                       │
    │                   conditional      ┌───▼───┐                  │
    │                     edge           │  END   │                  │
    │                        │           └───────┘                   │
    │                   ┌────▼─────┐                                 │
    │                   │  Node C  │──── loops back ──▶ Node A      │
    │                   └──────────┘                                 │
    │                                                                │
    │   ┌─────────────────────────────────────────────────────────┐  │
    │   │              State (TypedDict / Pydantic)               │  │
    │   │  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐  │  │
    │   │  │ messages  │  │ custom keys  │  │ reducers         │  │  │
    │   │  │(add_msgs) │  │ (overwrite)  │  │ (Annotated+fn)   │  │  │
    │   │  └──────────┘  └──────────────┘  └──────────────────┘  │  │
    │   └─────────────────────────────────────────────────────────┘  │
    │                                                                │
    │   ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
    │   │ Checkpointer │  │    Store      │  │  Stream Writer   │   │
    │   │ (persistence)│  │ (cross-thread)│  │  (custom events) │   │
    │   └──────────────┘  └──────────────┘  └──────────────────┘   │
    └─────────────────────────────────────────────────────────────────┘
```

### Core Primitives

| Primitive | Purpose |
|-----------|---------|
| `StateGraph` | Main graph builder — defines nodes, edges, and state schema |
| `START` / `END` | Entry and terminal constants |
| `add_node()` | Register a function as a graph node |
| `add_edge()` | Static routing between nodes |
| `add_conditional_edges()` | Dynamic routing based on state |
| `compile()` | Finalize graph — required before execution |
| `Command` | Combine state update + routing in a single return |
| `Send` | Fan-out to dynamic number of node instances (map-reduce) |
| `interrupt()` | Pause execution for human input |
| `@task` | Wrap side-effecting operations for durable execution |

---

## NON-NEGOTIABLE RULES

1. **Always call `compile()` before invoking a graph.** Uncompiled graphs raise errors.
2. **Never mutate state directly.** Nodes return dicts with keys to update; reducers handle merging.
3. **Always use `Annotated[list, add_messages]` for message lists.** Raw list overwrites lose history.
4. **Every graph with persistence MUST have a `thread_id` in config.** No thread_id = no state recovery.
5. **Never wrap `interrupt()` in try/except.** It raises a special exception internally.
6. **Keep `interrupt()` call order deterministic.** Conditional skipping causes index mismatch on resume.
7. **Pre-interrupt side effects MUST be idempotent.** Nodes re-execute from the start on resume.
8. **Use `@task` for non-deterministic / side-effecting operations** in durable execution mode.
9. **Never import LangChain where LangGraph suffices.** LangGraph works standalone.
10. **Always set `recursion_limit` for production graphs.** Default is 1000 — too high for most agents.
11. **Use `version="v2"` for streaming.** V1 format is inconsistent across modes.
12. **Type-hint node return types with `Command[Literal[...]]`** when using Command for routing.
13. **Run `ruff format` and `ruff check` before every commit.**

---

## PROJECT STRUCTURE

```
my_agent/
├── pyproject.toml
├── langgraph.json              # LangGraph Platform config (optional)
├── .env                        # API keys (never commit)
├── src/
│   └── my_agent/
│       ├── __init__.py
│       ├── graph.py            # Graph definition (StateGraph + compile)
│       ├── state.py            # State schema (TypedDict / Pydantic)
│       ├── nodes/
│       │   ├── __init__.py
│       │   ├── llm_call.py     # LLM invocation node
│       │   ├── tool_executor.py # Tool execution node
│       │   └── router.py       # Conditional edge functions
│       ├── tools/
│       │   ├── __init__.py
│       │   ├── search.py       # Tool definitions
│       │   └── database.py
│       ├── subgraphs/
│       │   ├── __init__.py
│       │   └── research.py     # Subgraph definitions
│       ├── prompts/
│       │   ├── __init__.py
│       │   └── system.py       # System prompt templates
│       ├── persistence/
│       │   ├── __init__.py
│       │   └── checkpointer.py # Checkpointer factory
│       └── config.py           # Context schema, constants
├── tests/
│   ├── __init__.py
│   ├── conftest.py             # Fixtures: graphs, checkpointers
│   ├── test_graph.py           # Integration tests
│   ├── test_nodes.py           # Unit tests for nodes
│   ├── test_tools.py           # Unit tests for tools
│   └── test_state.py           # State reducer tests
└── scripts/
    └── visualize.py            # Graph visualization helper
```

### pyproject.toml (minimal)

```toml
[project]
name = "my-agent"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "langgraph>=1.2.0",
    "langchain-anthropic>=0.3.0",
    "pydantic>=2.7.4",
]

[project.optional-dependencies]
postgres = ["langgraph-checkpoint-postgres>=2.0.0"]
sqlite = ["langgraph-checkpoint-sqlite>=2.0.0"]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.24",
    "ruff>=0.8.0",
]

[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM", "TCH"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

---

## CORE PATTERNS

### 1. StateGraph — Minimal Working Graph

```python
"""Minimal graph: START -> greet -> END."""

from langgraph.graph import StateGraph, START, END
from typing_extensions import TypedDict


class State(TypedDict):
    name: str
    greeting: str


def greet(state: State) -> dict:
    """Generate a greeting from the name."""
    return {"greeting": f"Hello, {state['name']}!"}


builder = StateGraph(State)
builder.add_node("greet", greet)
builder.add_edge(START, "greet")
builder.add_edge("greet", END)

graph = builder.compile()

# Invoke
result = graph.invoke({"name": "Alice"})
assert result["greeting"] == "Hello, Alice!"
```

### 2. Conditional Edges — Dynamic Routing

```python
"""Route based on state content."""

from typing import Literal

from langgraph.graph import StateGraph, START, END
from typing_extensions import TypedDict


class State(TypedDict):
    query: str
    category: str
    response: str


def classify(state: State) -> dict:
    """Classify the query into a category."""
    query = state["query"].lower()
    if "weather" in query:
        return {"category": "weather"}
    elif "math" in query:
        return {"category": "math"}
    return {"category": "general"}


def route_by_category(state: State) -> Literal["weather", "math", "general"]:
    """Route to the appropriate handler node."""
    return state["category"]


def weather_handler(state: State) -> dict:
    return {"response": "Checking weather..."}


def math_handler(state: State) -> dict:
    return {"response": "Calculating..."}


def general_handler(state: State) -> dict:
    return {"response": "Let me help with that."}


builder = StateGraph(State)
builder.add_node("classify", classify)
builder.add_node("weather", weather_handler)
builder.add_node("math", math_handler)
builder.add_node("general", general_handler)

builder.add_edge(START, "classify")
builder.add_conditional_edges(
    "classify",
    route_by_category,
    {"weather": "weather", "math": "math", "general": "general"},
)
builder.add_edge("weather", END)
builder.add_edge("math", END)
builder.add_edge("general", END)

graph = builder.compile()
```

### 3. Conditional Edges with Path Map (shorthand)

```python
# When the routing function returns node names directly,
# no explicit map is needed:
builder.add_conditional_edges(
    "classify",
    route_by_category,
    ["weather", "math", "general"],  # list of valid destinations
)
```

### 4. Command — Combined State Update + Routing

```python
"""Use Command to update state AND route in one return."""

from typing import Literal

from langgraph.graph import StateGraph, START, END
from langgraph.types import Command
from typing_extensions import TypedDict


class State(TypedDict):
    input: str
    step: str
    result: str


def analyze(state: State) -> Command[Literal["summarize", "translate"]]:
    """Analyze input and route to next step."""
    if len(state["input"]) > 100:
        return Command(
            update={"step": "summarize"},
            goto="summarize",
        )
    return Command(
        update={"step": "translate"},
        goto="translate",
    )


def summarize(state: State) -> dict:
    return {"result": f"Summary of: {state['input'][:50]}..."}


def translate(state: State) -> dict:
    return {"result": f"Translated: {state['input']}"}


builder = StateGraph(State)
builder.add_node("analyze", analyze)
builder.add_node("summarize", summarize)
builder.add_node("translate", translate)

builder.add_edge(START, "analyze")
builder.add_edge("summarize", END)
builder.add_edge("translate", END)

graph = builder.compile()
```

### 5. Send — Map-Reduce / Fan-Out

```python
"""Fan out to dynamic number of parallel nodes."""

import operator
from typing import Annotated

from langgraph.graph import StateGraph, START, END
from langgraph.types import Send
from typing_extensions import TypedDict


class OverallState(TypedDict):
    subjects: list[str]
    jokes: Annotated[list[str], operator.add]


class JokeState(TypedDict):
    subject: str


def generate_topics(state: OverallState) -> dict:
    return {"subjects": ["cats", "dogs", "parrots"]}


def fan_out_jokes(state: OverallState) -> list[Send]:
    """Create a Send for each subject — each runs generate_joke."""
    return [
        Send("generate_joke", {"subject": s})
        for s in state["subjects"]
    ]


def generate_joke(state: JokeState) -> dict:
    return {"jokes": [f"Why did the {state['subject']} cross the road?"]}


builder = StateGraph(OverallState)
builder.add_node("generate_topics", generate_topics)
builder.add_node("generate_joke", generate_joke)

builder.add_edge(START, "generate_topics")
builder.add_conditional_edges("generate_topics", fan_out_jokes)
builder.add_edge("generate_joke", END)

graph = builder.compile()
result = graph.invoke({"subjects": [], "jokes": []})
assert len(result["jokes"]) == 3
```

### 6. Looping Pattern — Agent Loop

```python
"""Classic agent loop: LLM decides when to stop."""

from typing import Literal

from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.graph import MessagesState, StateGraph, START, END


model = ChatAnthropic(model="claude-sonnet-4-20250514")


def call_llm(state: MessagesState) -> dict:
    """Invoke LLM with current messages."""
    response = model.invoke(state["messages"])
    return {"messages": [response]}


def should_continue(state: MessagesState) -> Literal["call_llm", "__end__"]:
    """Continue if the LLM made tool calls, otherwise end."""
    last = state["messages"][-1]
    if hasattr(last, "tool_calls") and last.tool_calls:
        return "call_llm"
    return END


builder = StateGraph(MessagesState)
builder.add_node("call_llm", call_llm)
builder.add_edge(START, "call_llm")
builder.add_conditional_edges("call_llm", should_continue)

graph = builder.compile()
```

---

## STATE MANAGEMENT

### TypedDict State (recommended for most cases)

```python
from typing import Annotated
from typing_extensions import TypedDict

from langgraph.graph.message import add_messages


class AgentState(TypedDict):
    """Agent state with message history and metadata.

    Attributes:
        messages: Conversation history. Uses add_messages reducer
            to append instead of overwrite.
        current_tool: Name of the tool being executed.
        retry_count: Number of retries attempted.
    """

    messages: Annotated[list, add_messages]
    current_tool: str
    retry_count: int
```

### Pydantic State (runtime validation)

```python
import operator
from typing import Annotated

from pydantic import BaseModel, Field

from langgraph.graph.message import add_messages


class AgentState(BaseModel):
    """State with Pydantic validation.

    Note: Pydantic state validates INPUT to the first node.
    Graph outputs are NOT Pydantic instances — they are dicts.
    """

    messages: Annotated[list, add_messages] = Field(default_factory=list)
    score: Annotated[float, operator.add] = 0.0
    tags: Annotated[list[str], operator.add] = Field(default_factory=list)
```

### Dataclass State (default values without Pydantic overhead)

```python
from dataclasses import dataclass, field
from typing import Annotated

from langgraph.graph.message import add_messages


@dataclass
class AgentState:
    """State with defaults using dataclass."""

    messages: Annotated[list, add_messages] = field(default_factory=list)
    iteration: int = 0
    max_iterations: int = 5
```

### Reducers Deep-Dive

```python
import operator
from typing import Annotated

from typing_extensions import TypedDict

from langgraph.graph.message import add_messages


def deduplicate_reducer(existing: list[str], new: list[str]) -> list[str]:
    """Custom reducer that deduplicates items."""
    return list(dict.fromkeys(existing + new))


class State(TypedDict):
    # DEFAULT: overwrite — last writer wins
    status: str

    # APPEND: operator.add concatenates lists
    results: Annotated[list[str], operator.add]

    # MESSAGES: add_messages handles message IDs, dedup, removal
    messages: Annotated[list, add_messages]

    # CUSTOM: any callable (existing, new) -> merged
    tags: Annotated[list[str], deduplicate_reducer]

    # COUNTER: operator.add works on numbers too
    step_count: Annotated[int, operator.add]
```

### Input/Output Schemas

```python
from langgraph.graph import StateGraph
from typing_extensions import TypedDict


class InputState(TypedDict):
    """Only these keys are accepted as graph input."""
    user_input: str


class OutputState(TypedDict):
    """Only these keys are returned as graph output."""
    final_answer: str


class OverallState(TypedDict):
    """Internal state — superset of input and output."""
    user_input: str
    intermediate_result: str
    final_answer: str


builder = StateGraph(
    OverallState,
    input_schema=InputState,
    output_schema=OutputState,
)
```

### MessagesState (prebuilt convenience)

```python
from langgraph.graph import MessagesState


class State(MessagesState):
    """Extends the prebuilt MessagesState.

    MessagesState already has:
        messages: Annotated[list[AnyMessage], add_messages]

    Add your own keys below.
    """

    documents: list[str]
    query: str
```

### RemainingSteps — Track Recursion Budget

```python
from typing import Annotated

from langgraph.managed import RemainingSteps
from typing_extensions import TypedDict


class State(TypedDict):
    messages: list
    remaining_steps: RemainingSteps


def reasoning_node(state: State) -> dict:
    """Wrap up early if running out of steps."""
    if state["remaining_steps"] <= 2:
        return {"messages": ["Running low on steps — wrapping up."]}
    return {"messages": ["Still thinking..."]}
```

---

## TOOL INTEGRATION

### Pattern 1: Manual Tool Node (full control)

```python
"""Manual tool execution with explicit routing."""

from typing import Literal

from langchain_anthropic import ChatAnthropic
from langchain_core.messages import ToolMessage
from langchain_core.tools import tool
from langgraph.graph import MessagesState, StateGraph, START, END


@tool
def search(query: str) -> str:
    """Search the web for information."""
    return f"Results for: {query}"


@tool
def calculator(expression: str) -> str:
    """Evaluate a math expression."""
    return str(eval(expression))  # noqa: S307


tools = [search, calculator]
tools_by_name = {t.name: t for t in tools}

model = ChatAnthropic(model="claude-sonnet-4-20250514")
model_with_tools = model.bind_tools(tools)


def call_llm(state: MessagesState) -> dict:
    """Call LLM with tools bound."""
    response = model_with_tools.invoke(state["messages"])
    return {"messages": [response]}


def tool_node(state: MessagesState) -> dict:
    """Execute all tool calls from the last LLM message."""
    results = []
    for tool_call in state["messages"][-1].tool_calls:
        tool_fn = tools_by_name[tool_call["name"]]
        result = tool_fn.invoke(tool_call["args"])
        results.append(
            ToolMessage(
                content=str(result),
                tool_call_id=tool_call["id"],
            )
        )
    return {"messages": results}


def should_continue(
    state: MessagesState,
) -> Literal["tool_node", "__end__"]:
    """Route to tools if the LLM requested them."""
    last = state["messages"][-1]
    if last.tool_calls:
        return "tool_node"
    return END


builder = StateGraph(MessagesState)
builder.add_node("call_llm", call_llm)
builder.add_node("tool_node", tool_node)

builder.add_edge(START, "call_llm")
builder.add_conditional_edges("call_llm", should_continue, ["tool_node", END])
builder.add_edge("tool_node", "call_llm")

agent = builder.compile()
```

### Pattern 2: Prebuilt ToolNode (less boilerplate)

```python
"""Using langgraph.prebuilt.ToolNode for automatic tool execution."""

from langgraph.prebuilt import ToolNode

# Define tools as before
tools = [search, calculator]
tool_node = ToolNode(tools)

builder = StateGraph(MessagesState)
builder.add_node("call_llm", call_llm)
builder.add_node("tools", tool_node)

builder.add_edge(START, "call_llm")
builder.add_conditional_edges("call_llm", should_continue, ["tools", END])
builder.add_edge("tools", "call_llm")

agent = builder.compile()
```

### Pattern 3: Tool with Interrupt (approval gate)

```python
"""Tool that requires human approval before executing."""

from langchain_core.tools import tool
from langgraph.types import interrupt


@tool
def send_email(to: str, subject: str, body: str) -> str:
    """Send an email. Requires human approval."""
    response = interrupt({
        "action": "send_email",
        "to": to,
        "subject": subject,
        "body": body,
        "message": "Approve sending this email?",
    })

    if response.get("action") == "approve":
        # Actually send the email
        return f"Email sent to {response.get('to', to)}"
    return "Email cancelled by user."
```

### Pattern 4: Streaming from Tools

```python
"""Emit custom stream events from tools."""

from langchain_core.tools import tool
from langgraph.config import get_stream_writer


@tool
def long_running_search(query: str) -> str:
    """Search with progress updates via streaming."""
    writer = get_stream_writer()

    writer({"status": "Starting search...", "progress": 0})
    results = _phase_1_search(query)

    writer({"status": "Analyzing results...", "progress": 50})
    analysis = _phase_2_analyze(results)

    writer({"status": "Complete", "progress": 100})
    return analysis
```

### Pattern 5: Context Schema for Tool Dependencies

```python
"""Inject dependencies (DB connections, API clients) via context."""

from dataclasses import dataclass

from langgraph.graph import StateGraph, MessagesState
from langgraph.runtime import Runtime


@dataclass
class AppContext:
    """Runtime dependencies injected into nodes."""

    db_url: str = "postgresql://localhost/mydb"
    api_key: str = ""
    model_name: str = "claude-sonnet-4-20250514"


def call_llm(state: MessagesState, runtime: Runtime[AppContext]) -> dict:
    """Access context for dynamic configuration."""
    model = get_model(runtime.context.model_name)
    response = model.invoke(state["messages"])
    return {"messages": [response]}


builder = StateGraph(MessagesState, context_schema=AppContext)
builder.add_node("call_llm", call_llm)
# ... add edges ...

graph = builder.compile()

# Invoke with context
result = graph.invoke(
    {"messages": [{"role": "user", "content": "Hello"}]},
    context=AppContext(model_name="claude-sonnet-4-20250514"),
)
```

---

## CHECKPOINTING AND PERSISTENCE

### MemorySaver (development / testing)

```python
"""In-memory checkpointer — data lost on process exit."""

from langgraph.checkpoint.memory import MemorySaver, InMemorySaver

checkpointer = MemorySaver()  # Alias for InMemorySaver
graph = builder.compile(checkpointer=checkpointer)

config = {"configurable": {"thread_id": "user-123"}}
result = graph.invoke({"messages": [{"role": "user", "content": "Hi"}]}, config)

# Continue the same conversation
result = graph.invoke(
    {"messages": [{"role": "user", "content": "What did I say?"}]},
    config,
)
```

### PostgresSaver (production)

```python
"""Postgres checkpointer for production workloads."""

from langgraph.checkpoint.postgres import PostgresSaver

DB_URI = "postgresql://user:pass@localhost:5432/langgraph"

# Sync usage
with PostgresSaver.from_conn_string(DB_URI) as checkpointer:
    checkpointer.setup()  # Create tables on first run
    graph = builder.compile(checkpointer=checkpointer)

    config = {"configurable": {"thread_id": "prod-thread-1"}}
    result = graph.invoke(inputs, config)
```

### AsyncPostgresSaver (async production)

```python
"""Async Postgres checkpointer for async graphs."""

from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver

DB_URI = "postgresql://user:pass@localhost:5432/langgraph"


async def main():
    async with AsyncPostgresSaver.from_conn_string(DB_URI) as checkpointer:
        await checkpointer.setup()
        graph = builder.compile(checkpointer=checkpointer)

        config = {"configurable": {"thread_id": "async-thread-1"}}
        result = await graph.ainvoke(inputs, config)
```

### SqliteSaver (lightweight persistence)

```python
"""SQLite checkpointer for single-process persistence."""

import sqlite3

from langgraph.checkpoint.sqlite import SqliteSaver

conn = sqlite3.connect("checkpoints.db", check_same_thread=False)
checkpointer = SqliteSaver(conn)
checkpointer.setup()

graph = builder.compile(checkpointer=checkpointer)
```

### State Inspection and Time Travel

```python
"""Inspect state history and replay from prior checkpoints."""

from langgraph.checkpoint.memory import MemorySaver

checkpointer = MemorySaver()
graph = builder.compile(checkpointer=checkpointer)
config = {"configurable": {"thread_id": "debug-1"}}

# Run the graph
graph.invoke(inputs, config)

# Get current state
snapshot = graph.get_state(config)
print(snapshot.values)     # Current state values
print(snapshot.next)       # Tuple of next nodes (empty = done)
print(snapshot.metadata)   # Step count, source, writes

# Browse history (most recent first)
for state in graph.get_state_history(config):
    print(f"Step {state.metadata['step']}: next={state.next}")

# Replay from a specific checkpoint
old_config = {
    "configurable": {
        "thread_id": "debug-1",
        "checkpoint_id": "1ef663ba-xxxx",
    }
}
graph.invoke(None, old_config)  # Resume from that point

# Fork: update state and continue
graph.update_state(config, {"status": "override"}, as_node="my_node")
graph.invoke(None, config)  # Continues with updated state
```

### Store — Cross-Thread Long-Term Memory

```python
"""Use Store for memories that persist across threads."""

import uuid
from dataclasses import dataclass

from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.runtime import Runtime
from langgraph.store.memory import InMemoryStore


@dataclass
class UserContext:
    user_id: str


store = InMemoryStore()
checkpointer = MemorySaver()


async def save_memory(
    state: MessagesState,
    runtime: Runtime[UserContext],
) -> dict:
    """Extract and save a memory from the conversation."""
    namespace = (runtime.context.user_id, "memories")
    memory_id = str(uuid.uuid4())
    last_content = state["messages"][-1].content
    await runtime.store.aput(
        namespace,
        memory_id,
        {"content": last_content},
    )
    return {}


async def recall_memories(
    state: MessagesState,
    runtime: Runtime[UserContext],
) -> dict:
    """Retrieve relevant memories for context."""
    namespace = (runtime.context.user_id, "memories")
    query = state["messages"][-1].content
    memories = await runtime.store.asearch(namespace, query=query, limit=5)
    context = "\n".join(m.value["content"] for m in memories)
    return {"messages": [{"role": "system", "content": f"Memories:\n{context}"}]}


builder = StateGraph(MessagesState, context_schema=UserContext)
builder.add_node("recall", recall_memories)
builder.add_node("save", save_memory)
# ... add other nodes and edges ...

graph = builder.compile(checkpointer=checkpointer, store=store)

# Same user, different threads — memories persist
config_t1 = {"configurable": {"thread_id": "t1"}}
config_t2 = {"configurable": {"thread_id": "t2"}}

await graph.ainvoke(
    {"messages": [{"role": "user", "content": "I love pizza"}]},
    config_t1,
    context=UserContext(user_id="alice"),
)

# Later, on a different thread, memories are available
await graph.ainvoke(
    {"messages": [{"role": "user", "content": "What food do I like?"}]},
    config_t2,
    context=UserContext(user_id="alice"),
)
```

### Store with Semantic Search

```python
"""Enable vector-based memory retrieval."""

from langchain.embeddings import init_embeddings
from langgraph.store.memory import InMemoryStore

store = InMemoryStore(
    index={
        "embed": init_embeddings("openai:text-embedding-3-small"),
        "dims": 1536,
        "fields": ["content", "$"],  # Fields to embed
    }
)

# Store a memory
store.put(
    ("user-1", "preferences"),
    "pref-1",
    {"content": "Prefers dark mode and vim keybindings"},
    index=["content"],  # Only embed this field
)

# Search semantically
results = store.search(
    ("user-1", "preferences"),
    query="What editor settings does the user prefer?",
    limit=3,
)
```

### Encrypted Checkpoints

```python
"""Encrypt checkpoint data at rest."""

import sqlite3

from langgraph.checkpoint.serde.encrypted import EncryptedSerializer
from langgraph.checkpoint.sqlite import SqliteSaver

# Set LANGGRAPH_AES_KEY env var first
serde = EncryptedSerializer.from_pycryptodome_aes()
conn = sqlite3.connect("encrypted_checkpoints.db")
checkpointer = SqliteSaver(conn, serde=serde)
checkpointer.setup()
```

---

## HUMAN-IN-THE-LOOP PATTERNS

### Pattern 1: Simple Approval Gate

```python
"""Pause for human approval before a critical action."""

from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command, interrupt
from typing_extensions import TypedDict


class State(TypedDict):
    action: str
    approved: bool
    result: str


def plan_action(state: State) -> dict:
    return {"action": "Delete all records from staging"}


def approval_gate(state: State) -> dict:
    """Pause and ask for human approval."""
    decision = interrupt({
        "question": "Do you approve this action?",
        "action": state["action"],
    })
    return {"approved": decision}


def execute_action(state: State) -> dict:
    if state["approved"]:
        return {"result": f"Executed: {state['action']}"}
    return {"result": "Action cancelled."}


builder = StateGraph(State)
builder.add_node("plan", plan_action)
builder.add_node("approve", approval_gate)
builder.add_node("execute", execute_action)

builder.add_edge(START, "plan")
builder.add_edge("plan", "approve")
builder.add_edge("approve", "execute")
builder.add_edge("execute", END)

graph = builder.compile(checkpointer=MemorySaver())

# Step 1: Run until interrupt
config = {"configurable": {"thread_id": "approval-1"}}
result = graph.invoke({"action": "", "approved": False, "result": ""}, config)
# Graph pauses at approval_gate

# Step 2: Resume with human decision
result = graph.invoke(Command(resume=True), config)
assert result["approved"] is True
```

### Pattern 2: Review and Edit

```python
"""Let human review and edit LLM output before proceeding."""

from langgraph.types import interrupt


def generate_draft(state: State) -> dict:
    draft = llm.invoke("Write a summary of: " + state["topic"])
    return {"draft": draft.content}


def human_review(state: State) -> dict:
    """Pause for human to review/edit the draft."""
    edited = interrupt({
        "instruction": "Review and edit this draft",
        "content": state["draft"],
    })
    # edited contains whatever the human provided
    return {"draft": edited}
```

### Pattern 3: Validation Loop

```python
"""Re-prompt until valid input is provided."""

from langgraph.types import interrupt


def get_validated_input(state: State) -> dict:
    """Loop until user provides valid input."""
    prompt = "Enter your age (positive integer):"

    while True:
        answer = interrupt(prompt)
        if isinstance(answer, int) and answer > 0:
            return {"age": answer}
        prompt = f"'{answer}' is invalid. Enter a positive integer:"
```

### Pattern 4: Multiple Simultaneous Interrupts

```python
"""Handle parallel branches that both need approval."""

import operator
from typing import Annotated

from langgraph.graph import StateGraph, START, END
from langgraph.types import Command, interrupt
from typing_extensions import TypedDict


class State(TypedDict):
    results: Annotated[list[str], operator.add]


def branch_a(state: State) -> dict:
    answer = interrupt("Approve branch A?")
    return {"results": [f"a:{answer}"]}


def branch_b(state: State) -> dict:
    answer = interrupt("Approve branch B?")
    return {"results": [f"b:{answer}"]}


# After invoking and hitting both interrupts:
# result["__interrupt__"] contains both interrupt payloads.
# Resume all at once with a mapping:
# resume_map = {i.id: "yes" for i in result["__interrupt__"]}
# graph.invoke(Command(resume=resume_map), config)
```

### Pattern 5: Static Breakpoints (debugging)

```python
"""Use interrupt_before / interrupt_after for step-through debugging."""

from langgraph.checkpoint.memory import MemorySaver

# At compile time
graph = builder.compile(
    checkpointer=MemorySaver(),
    interrupt_before=["critical_node"],
    interrupt_after=["verification_node"],
)

config = {"configurable": {"thread_id": "debug-1"}}
graph.invoke(inputs, config)  # Pauses before critical_node
graph.invoke(None, config)    # Resumes from breakpoint

# At runtime (per-invocation)
graph.invoke(
    inputs,
    config,
    interrupt_before=["some_node"],
)
```

### Pattern 6: V2 Streaming with Interrupts

```python
"""Detect interrupts in streaming mode and resume."""

from langgraph.types import Command


async def run_with_hitl(graph, inputs, config):
    """Run graph with streaming HITL support."""
    current_input = inputs

    while True:
        interrupted = False
        async for chunk in graph.astream(
            current_input,
            stream_mode=["messages", "updates"],
            config=config,
            version="v2",
        ):
            if chunk["type"] == "messages":
                msg, metadata = chunk["data"]
                if hasattr(msg, "content") and msg.content:
                    print(msg.content, end="", flush=True)

            elif chunk["type"] == "updates":
                if "__interrupt__" in chunk["data"]:
                    interrupt_info = chunk["data"]["__interrupt__"][0].value
                    user_response = input(f"\n{interrupt_info}: ")
                    current_input = Command(resume=user_response)
                    interrupted = True
                    break

        if not interrupted:
            break
```

### Critical Rules for interrupt()

```python
# 1. NEVER wrap in try/except
# BAD:
try:
    answer = interrupt("question")  # interrupt raises internally
except Exception:
    pass

# GOOD:
answer = interrupt("question")
try:
    result = do_something(answer)  # separate concerns
except SpecificError:
    handle_error()

# 2. KEEP call order deterministic
# BAD: conditional skip causes index mismatch
if some_condition:
    interrupt("Q1")
interrupt("Q2")

# GOOD: always same order
name = interrupt("Name?")
age = interrupt("Age?")

# 3. Only JSON-serializable payloads
# BAD:
interrupt({"callback": lambda x: x})

# GOOD:
interrupt({"question": "Approve?", "details": {"amount": 100}})

# 4. Pre-interrupt side effects MUST be idempotent
# BAD: creates duplicate on replay
db.insert(record)
answer = interrupt("Continue?")

# GOOD: upsert is safe to replay
db.upsert(record_id, record)
answer = interrupt("Continue?")
```

---

## MULTI-AGENT / SUBGRAPH PATTERNS

### Pattern 1: Subgraph with Shared State

```python
"""Add a compiled subgraph directly when state schemas overlap."""

from langgraph.graph import MessagesState, StateGraph, START, END


# --- Subgraph ---
def research_node(state: MessagesState) -> dict:
    return {"messages": [{"role": "assistant", "content": "Research done."}]}


sub_builder = StateGraph(MessagesState)
sub_builder.add_node("research", research_node)
sub_builder.add_edge(START, "research")
sub_builder.add_edge("research", END)
research_subgraph = sub_builder.compile()


# --- Parent graph ---
def orchestrator(state: MessagesState) -> dict:
    return {"messages": [{"role": "assistant", "content": "Orchestrating..."}]}


parent_builder = StateGraph(MessagesState)
parent_builder.add_node("orchestrator", orchestrator)
parent_builder.add_node("research", research_subgraph)  # Subgraph as node

parent_builder.add_edge(START, "orchestrator")
parent_builder.add_edge("orchestrator", "research")
parent_builder.add_edge("research", END)

parent_graph = parent_builder.compile()
```

### Pattern 2: Subgraph with Different State (wrapper)

```python
"""Transform state when parent and child have different schemas."""

from langgraph.graph import StateGraph, START, END
from typing_extensions import TypedDict


class ParentState(TypedDict):
    query: str
    answer: str


class ChildState(TypedDict):
    input_text: str
    output_text: str


def child_node(state: ChildState) -> dict:
    return {"output_text": f"Processed: {state['input_text']}"}


child_builder = StateGraph(ChildState)
child_builder.add_node("process", child_node)
child_builder.add_edge(START, "process")
child_builder.add_edge("process", END)
child_graph = child_builder.compile()


def call_child(state: ParentState) -> dict:
    """Wrapper that transforms between parent and child state."""
    child_result = child_graph.invoke({"input_text": state["query"]})
    return {"answer": child_result["output_text"]}


parent_builder = StateGraph(ParentState)
parent_builder.add_node("process", call_child)
parent_builder.add_edge(START, "process")
parent_builder.add_edge("process", END)
parent_graph = parent_builder.compile()
```

### Pattern 3: Supervisor Agent

```python
"""Supervisor routes tasks to specialized sub-agents."""

from typing import Literal

from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool
from langgraph.graph import MessagesState, StateGraph, START, END
from langgraph.prebuilt import ToolNode


@tool
def search_web(query: str) -> str:
    """Search the web for information."""
    return f"Web results for: {query}"


@tool
def query_database(sql: str) -> str:
    """Query the internal database."""
    return f"DB results for: {sql}"


# Sub-agent builders
def build_researcher() -> StateGraph:
    """Build the research sub-agent."""
    model = ChatAnthropic(model="claude-sonnet-4-20250514").bind_tools([search_web])

    def call_researcher(state: MessagesState) -> dict:
        response = model.invoke([
            SystemMessage(content="You are a web researcher."),
            *state["messages"],
        ])
        return {"messages": [response]}

    builder = StateGraph(MessagesState)
    builder.add_node("call", call_researcher)
    builder.add_node("tools", ToolNode([search_web]))
    builder.add_edge(START, "call")
    builder.add_conditional_edges(
        "call",
        lambda s: "tools" if s["messages"][-1].tool_calls else END,
        ["tools", END],
    )
    builder.add_edge("tools", "call")
    return builder.compile()


def build_analyst() -> StateGraph:
    """Build the analyst sub-agent."""
    model = ChatAnthropic(model="claude-sonnet-4-20250514").bind_tools([query_database])

    def call_analyst(state: MessagesState) -> dict:
        response = model.invoke([
            SystemMessage(content="You are a data analyst."),
            *state["messages"],
        ])
        return {"messages": [response]}

    builder = StateGraph(MessagesState)
    builder.add_node("call", call_analyst)
    builder.add_node("tools", ToolNode([query_database]))
    builder.add_edge(START, "call")
    builder.add_conditional_edges(
        "call",
        lambda s: "tools" if s["messages"][-1].tool_calls else END,
        ["tools", END],
    )
    builder.add_edge("tools", "call")
    return builder.compile()


researcher = build_researcher()
analyst = build_analyst()


# Supervisor
supervisor_model = ChatAnthropic(model="claude-sonnet-4-20250514")


def supervisor(state: MessagesState) -> dict:
    """Decide which sub-agent to route to."""
    response = supervisor_model.invoke([
        SystemMessage(content=(
            "You are a supervisor. Route the user's request to either "
            "'researcher' (web search) or 'analyst' (database queries). "
            "Respond with just the agent name."
        )),
        *state["messages"],
    ])
    return {"messages": [response]}


def route_to_agent(
    state: MessagesState,
) -> Literal["researcher", "analyst", "__end__"]:
    """Route based on supervisor's decision."""
    last = state["messages"][-1].content.lower()
    if "researcher" in last:
        return "researcher"
    elif "analyst" in last:
        return "analyst"
    return END


parent_builder = StateGraph(MessagesState)
parent_builder.add_node("supervisor", supervisor)
parent_builder.add_node("researcher", researcher)
parent_builder.add_node("analyst", analyst)

parent_builder.add_edge(START, "supervisor")
parent_builder.add_conditional_edges(
    "supervisor",
    route_to_agent,
    ["researcher", "analyst", END],
)
parent_builder.add_edge("researcher", "supervisor")
parent_builder.add_edge("analyst", "supervisor")

supervisor_graph = parent_builder.compile()
```

### Pattern 4: Sub-Agents as Tools

```python
"""Wrap sub-agents as tools for the outer agent."""

from langchain_core.tools import tool


@tool
def ask_researcher(question: str) -> str:
    """Delegate research questions to the research agent."""
    result = researcher.invoke(
        {"messages": [{"role": "user", "content": question}]}
    )
    return result["messages"][-1].content


@tool
def ask_analyst(question: str) -> str:
    """Delegate data analysis to the analyst agent."""
    result = analyst.invoke(
        {"messages": [{"role": "user", "content": question}]}
    )
    return result["messages"][-1].content
```

### Pattern 5: Command with PARENT (cross-graph routing)

```python
"""Navigate from subgraph back to parent graph."""

from langgraph.types import Command


def subgraph_node(state: State) -> Command[Literal["parent_node"]]:
    """Complete subgraph work and route to a specific parent node."""
    return Command(
        update={"result": "subgraph done"},
        goto="parent_node",
        graph=Command.PARENT,
    )
```

### Subgraph Persistence Modes

```python
# Per-invocation (default) — each call starts fresh
agent = create_agent(model="claude-sonnet-4-20250514", tools=[my_tool])
# No checkpointer → inherits parent's, but resets per invocation

# Per-thread — state accumulates across calls
agent = create_agent(
    model="claude-sonnet-4-20250514",
    tools=[my_tool],
    checkpointer=True,  # Enables persistent memory
)

# Stateless — no checkpointing at all
agent = create_agent(
    model="claude-sonnet-4-20250514",
    tools=[my_tool],
    checkpointer=False,
)
```

---

## STREAMING PATTERNS

### Stream Modes Reference

| Mode | Description | Use Case |
|------|-------------|----------|
| `values` | Full state after each step | Debugging, state inspection |
| `updates` | State diff per node | UI updates, progress tracking |
| `messages` | LLM token chunks + metadata | Chat UIs, real-time display |
| `custom` | User-defined via `get_stream_writer()` | Progress bars, status updates |
| `checkpoints` | Persistence snapshots | Audit, replay |
| `tasks` | Node start/finish events | Monitoring, timing |
| `debug` | All metadata combined | Development, troubleshooting |

### Basic Streaming (V2)

```python
"""Stream with V2 format — unified StreamPart dict."""

for chunk in graph.stream(
    {"messages": [{"role": "user", "content": "Hello"}]},
    stream_mode="updates",
    version="v2",
):
    print(f"Type: {chunk['type']}")
    print(f"Namespace: {chunk['ns']}")
    print(f"Data: {chunk['data']}")
```

### Token-by-Token Streaming

```python
"""Stream LLM tokens as they arrive."""

for chunk in graph.stream(
    {"messages": [{"role": "user", "content": "Tell me a story"}]},
    stream_mode="messages",
    version="v2",
):
    if chunk["type"] == "messages":
        msg_chunk, metadata = chunk["data"]
        if msg_chunk.content:
            print(msg_chunk.content, end="", flush=True)
```

### Multiple Stream Modes

```python
"""Combine multiple modes in one stream call."""

for chunk in graph.stream(
    inputs,
    stream_mode=["updates", "messages", "custom"],
    version="v2",
):
    match chunk["type"]:
        case "updates":
            for node_name, state_update in chunk["data"].items():
                print(f"[{node_name}] updated: {state_update}")
        case "messages":
            msg, meta = chunk["data"]
            if msg.content:
                print(msg.content, end="", flush=True)
        case "custom":
            print(f"Custom event: {chunk['data']}")
```

### Custom Stream Writer

```python
"""Emit custom events from nodes and tools."""

from langgraph.config import get_stream_writer
from langgraph.types import StreamWriter


# Option 1: get_stream_writer() — works in Python >= 3.11
def my_node(state: State) -> dict:
    writer = get_stream_writer()
    writer({"stage": "preprocessing", "progress": 0.0})
    data = preprocess(state["input"])
    writer({"stage": "inference", "progress": 0.5})
    result = run_model(data)
    writer({"stage": "done", "progress": 1.0})
    return {"output": result}


# Option 2: StreamWriter parameter — required for Python < 3.11 async
async def my_async_node(state: State, writer: StreamWriter) -> dict:
    writer({"stage": "start"})
    result = await async_operation()
    writer({"stage": "complete"})
    return {"output": result}
```

### Async Streaming

```python
"""Async streaming for production servers."""

async def stream_agent_response(user_message: str, thread_id: str):
    """Stream agent response for a web endpoint."""
    config = {"configurable": {"thread_id": thread_id}}
    inputs = {"messages": [{"role": "user", "content": user_message}]}

    async for chunk in graph.astream(
        inputs,
        stream_mode=["messages", "custom"],
        config=config,
        version="v2",
    ):
        if chunk["type"] == "messages":
            msg, _ = chunk["data"]
            if msg.content:
                yield {"type": "token", "content": msg.content}
        elif chunk["type"] == "custom":
            yield {"type": "status", "data": chunk["data"]}
```

### Streaming Subgraph Events

```python
"""Capture streaming events from subgraphs."""

for chunk in graph.stream(
    inputs,
    subgraphs=True,
    stream_mode="updates",
    version="v2",
):
    ns = chunk["ns"]
    if ns == ():
        print(f"[root] {chunk['data']}")
    else:
        print(f"[subgraph:{ns}] {chunk['data']}")
```

### Filter Stream by Node

```python
"""Only process tokens from specific nodes."""

for chunk in graph.stream(
    inputs,
    stream_mode="messages",
    version="v2",
):
    if chunk["type"] == "messages":
        msg, metadata = chunk["data"]
        if metadata.get("langgraph_node") == "main_llm":
            print(msg.content, end="", flush=True)
```

### V2 Invoke (structured return)

```python
"""V2 invoke returns GraphOutput with .value and .interrupts."""

result = graph.invoke(inputs, config, version="v2")

print(result.value)       # The state output dict
print(result.interrupts)  # Tuple of Interrupt objects (if any)
```

---

## DURABLE EXECUTION

### Tasks for Side Effects

```python
"""Wrap non-deterministic operations in @task for safe replay."""

from langgraph.func import task


@task
def call_external_api(url: str) -> dict:
    """Task-wrapped API call — safe to replay on resume."""
    import requests
    response = requests.get(url, timeout=30)
    return response.json()


def my_node(state: State) -> dict:
    """Node that uses tasks for durable execution."""
    # Each task is individually checkpointed
    result_a = call_external_api(state["url_a"])
    result_b = call_external_api(state["url_b"])

    # .result() blocks until the task completes
    return {
        "data_a": result_a.result(),
        "data_b": result_b.result(),
    }
```

### Graceful Shutdown (v1.2+)

```python
"""Cooperative shutdown with RunControl."""

from langgraph.errors import GraphDrained
from langgraph.runtime import RunControl

control = RunControl()


def handle_sigterm(signum, frame):
    control.request_drain("sigterm")


import signal
signal.signal(signal.SIGTERM, handle_sigterm)

try:
    result = graph.invoke(inputs, config, control=control)
except GraphDrained as exc:
    print(f"Drained: {exc.reason}")
    # Resume later with same config + None input
    result = graph.invoke(None, config)
```

---

## TESTING PATTERNS

### Unit Testing Nodes

```python
"""Test individual node functions in isolation."""

import pytest
from my_agent.nodes.llm_call import call_llm
from my_agent.state import AgentState


def test_call_llm_returns_message():
    """Node should return a dict with messages key."""
    state: AgentState = {
        "messages": [{"role": "user", "content": "Hello"}],
        "current_tool": "",
        "retry_count": 0,
    }

    result = call_llm(state)

    assert "messages" in result
    assert len(result["messages"]) > 0
```

### Unit Testing Routing Functions

```python
"""Test conditional edge functions deterministically."""

from my_agent.nodes.router import should_continue


def test_should_continue_with_tool_calls():
    """Route to tool_node when LLM makes tool calls."""
    from langchain_core.messages import AIMessage

    state = {
        "messages": [
            AIMessage(
                content="",
                tool_calls=[{"name": "search", "args": {}, "id": "1"}],
            )
        ]
    }

    assert should_continue(state) == "tool_node"


def test_should_continue_without_tool_calls():
    """Route to END when no tool calls."""
    from langchain_core.messages import AIMessage

    state = {"messages": [AIMessage(content="Final answer.")]}

    assert should_continue(state) == "__end__"
```

### Integration Testing Graphs

```python
"""Test the full compiled graph end-to-end."""

import pytest
from langgraph.checkpoint.memory import MemorySaver

from my_agent.graph import build_graph


@pytest.fixture
def graph():
    """Provide a compiled graph with in-memory checkpointer."""
    return build_graph(checkpointer=MemorySaver())


@pytest.fixture
def config():
    return {"configurable": {"thread_id": "test-1"}}


def test_agent_answers_simple_question(graph, config):
    """Agent should produce a non-empty response."""
    result = graph.invoke(
        {"messages": [{"role": "user", "content": "What is 2+2?"}]},
        config,
    )

    assert len(result["messages"]) >= 2
    last_msg = result["messages"][-1]
    assert "4" in last_msg.content


def test_conversation_persistence(graph, config):
    """State should persist across invocations on same thread."""
    graph.invoke(
        {"messages": [{"role": "user", "content": "My name is Alice"}]},
        config,
    )

    result = graph.invoke(
        {"messages": [{"role": "user", "content": "What is my name?"}]},
        config,
    )

    last_msg = result["messages"][-1]
    assert "alice" in last_msg.content.lower()
```

### Testing Human-in-the-Loop

```python
"""Test interrupt and resume flow."""

from langgraph.types import Command


def test_approval_flow(graph, config):
    """Graph should pause at interrupt and resume with Command."""
    # Run until interrupt
    result = graph.invoke(
        {"messages": [{"role": "user", "content": "Send email to bob"}]},
        config,
    )

    # Verify graph paused
    snapshot = graph.get_state(config)
    assert snapshot.next  # Non-empty means graph is paused

    # Resume with approval
    result = graph.invoke(Command(resume=True), config)

    # Verify completion
    snapshot = graph.get_state(config)
    assert not snapshot.next  # Empty means graph is done
```

### Testing State Reducers

```python
"""Test custom reducers directly."""

from my_agent.state import deduplicate_reducer


def test_deduplicate_reducer():
    existing = ["a", "b", "c"]
    new = ["b", "c", "d"]

    result = deduplicate_reducer(existing, new)

    assert result == ["a", "b", "c", "d"]
    assert len(result) == 4  # No duplicates
```

### Testing with Mocked LLM

```python
"""Mock LLM responses for deterministic tests."""

from unittest.mock import patch

from langchain_core.messages import AIMessage


def test_agent_with_mocked_llm(config):
    """Test agent flow with predictable LLM responses."""
    mock_response = AIMessage(content="The answer is 42.")

    with patch("my_agent.nodes.llm_call.model") as mock_model:
        mock_model.invoke.return_value = mock_response

        from my_agent.graph import build_graph

        graph = build_graph()
        result = graph.invoke(
            {"messages": [{"role": "user", "content": "What is the answer?"}]},
            config,
        )

    assert "42" in result["messages"][-1].content
```

### Async Test Pattern

```python
"""Test async graphs with pytest-asyncio."""

import pytest


@pytest.mark.asyncio
async def test_async_graph():
    """Test async graph invocation."""
    from langgraph.checkpoint.memory import MemorySaver

    graph = build_graph(checkpointer=MemorySaver())
    config = {"configurable": {"thread_id": "async-test-1"}}

    result = await graph.ainvoke(
        {"messages": [{"role": "user", "content": "Hello"}]},
        config,
    )

    assert len(result["messages"]) >= 2
```

### Graph Visualization (debugging helper)

```python
"""Generate visual representation of the graph."""

from IPython.display import Image, display


def visualize_graph(graph) -> None:
    """Display the graph structure as a Mermaid diagram."""
    png_bytes = graph.get_graph(xray=True).draw_mermaid_png()
    display(Image(png_bytes))


# Or save to file
def save_graph_image(graph, path: str = "graph.png") -> None:
    """Save graph visualization to a PNG file."""
    png_bytes = graph.get_graph(xray=True).draw_mermaid_png()
    with open(path, "wb") as f:
        f.write(png_bytes)
```

---

## ANTI-PATTERNS

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| Mutating state directly in nodes | Breaks reducer semantics; causes inconsistent state | Return a dict with keys to update |
| `messages: list` without reducer | Each node overwrites the entire message list | `messages: Annotated[list, add_messages]` |
| Missing `thread_id` in config | No state persistence; checkpointer silently skips | Always pass `{"configurable": {"thread_id": "..."}}` |
| `try: interrupt(...) except:` | Catches the internal exception, skipping the pause | Never wrap `interrupt()` in try/except |
| Conditional `interrupt()` calls | Index mismatch on resume causes wrong value mapping | Keep interrupt call order deterministic |
| Non-idempotent pre-interrupt ops | Duplicate side effects on replay (double inserts, emails) | Use upserts, idempotency keys |
| `graph.invoke()` without `compile()` | Raises `AttributeError` or `TypeError` | Always call `builder.compile()` first |
| Huge state in checkpoints | Slow persistence, high storage cost | Use `input_schema`/`output_schema` to limit stored data |
| `recursion_limit=1000` in production | Infinite loops burn tokens and compute | Set explicit `recursion_limit` (e.g., 25-50) |
| Sharing mutable objects across nodes | Race conditions in parallel execution | Return new dicts/lists from each node |
| Using V1 stream format | Inconsistent output shape across modes | Use `version="v2"` for streaming |
| Putting secrets in state | Checkpointed to disk, visible in state history | Use context schema or env vars |
| Skipping `checkpointer.setup()` | Missing tables cause runtime errors (Postgres/SQLite) | Call `setup()` once before first use |
| `from langgraph.prebuilt import create_react_agent` in complex flows | Limited customization, opaque internals | Build with `StateGraph` for control |
| Nesting subgraphs without wrapper for different schemas | `KeyError` when state keys don't match | Use wrapper function to transform state |

---

## VERIFICATION CHECKLIST

Before considering a LangGraph agent complete, verify:

### Graph Structure
- [ ] All nodes registered with `add_node()`
- [ ] All edges defined (no orphan nodes)
- [ ] `START` edge points to entry node
- [ ] All terminal paths reach `END`
- [ ] `compile()` called before any invocation
- [ ] `recursion_limit` set to a reasonable value

### State
- [ ] Message lists use `Annotated[list, add_messages]`
- [ ] Custom reducers tested with edge cases (empty lists, duplicates)
- [ ] `input_schema` / `output_schema` defined if state is large
- [ ] No mutable default values in state schema
- [ ] Pydantic state: aware that output is dict, not model instance

### Persistence
- [ ] Checkpointer configured for all stateful flows
- [ ] `thread_id` passed in every `invoke()` / `stream()` call
- [ ] `checkpointer.setup()` called for Postgres/SQLite
- [ ] Store configured if cross-thread memory is needed

### Human-in-the-Loop
- [ ] `interrupt()` not wrapped in try/except
- [ ] `interrupt()` call order is deterministic
- [ ] Pre-interrupt side effects are idempotent
- [ ] Resume uses `Command(resume=value)` with correct thread_id
- [ ] Interrupt payloads are JSON-serializable

### Streaming
- [ ] Using `version="v2"` for consistent format
- [ ] Stream mode(s) appropriate for the use case
- [ ] Async nodes pass config explicitly on Python < 3.11
- [ ] Custom stream writer used for progress updates

### Testing
- [ ] Node functions tested in isolation
- [ ] Routing functions tested with all possible states
- [ ] Full graph tested end-to-end with MemorySaver
- [ ] HITL flows tested with interrupt/resume cycle
- [ ] State reducers tested with edge cases

### Security
- [ ] No secrets in state (use context or env vars)
- [ ] API keys loaded from environment, not hardcoded
- [ ] Encrypted checkpointer for sensitive data at rest
- [ ] `eval()` never used in tool implementations (use safe parsers)

---

## TECHNOLOGY REFERENCE

| Package | Purpose | Install |
|---------|---------|---------|
| `langgraph` | Core graph framework | `pip install langgraph>=1.2.0` |
| `langgraph-checkpoint` | Checkpoint base + MemorySaver | Included with langgraph |
| `langgraph-checkpoint-postgres` | PostgresSaver / AsyncPostgresSaver | `pip install langgraph-checkpoint-postgres` |
| `langgraph-checkpoint-sqlite` | SqliteSaver / AsyncSqliteSaver | `pip install langgraph-checkpoint-sqlite` |
| `langgraph-prebuilt` | ToolNode, create_react_agent | Included with langgraph |
| `langgraph-sdk` | Client SDK for LangGraph Platform | `pip install langgraph-sdk` |
| `langchain-anthropic` | Claude models via LangChain | `pip install langchain-anthropic` |
| `langchain-openai` | OpenAI models via LangChain | `pip install langchain-openai` |
| `langchain-core` | Base abstractions (messages, tools) | Included with langchain-* |
| `pydantic` | State validation (optional) | `pip install pydantic>=2.7.4` |
| `langsmith` | Tracing, debugging, evals | `pip install langsmith` |

### Key Imports Cheat Sheet

```python
# Graph building
from langgraph.graph import StateGraph, MessagesState, START, END

# Types and control flow
from langgraph.types import Command, Send, interrupt, CachePolicy, StreamWriter

# State management
from langgraph.graph.message import add_messages
from langgraph.managed import RemainingSteps

# Checkpointing
from langgraph.checkpoint.memory import MemorySaver, InMemorySaver
from langgraph.checkpoint.postgres import PostgresSaver
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver
from langgraph.checkpoint.sqlite import SqliteSaver

# Store (cross-thread memory)
from langgraph.store.memory import InMemoryStore

# Prebuilt components
from langgraph.prebuilt import ToolNode

# Runtime and config
from langgraph.runtime import Runtime, RunControl
from langgraph.config import get_stream_writer

# Durable execution
from langgraph.func import task, entrypoint

# Messages (from langchain-core)
from langchain_core.messages import (
    HumanMessage,
    AIMessage,
    SystemMessage,
    ToolMessage,
)
from langchain_core.tools import tool
```

---

## NAMING CONVENTIONS

| Element | Convention | Example |
|---------|-----------|---------|
| State class | `CapWords` + `State` suffix | `AgentState`, `ResearchState` |
| Node function | `lower_with_under`, verb-first | `call_llm`, `execute_tools`, `classify_query` |
| Routing function | `lower_with_under`, describes decision | `should_continue`, `route_by_category` |
| Tool function | `lower_with_under`, action-oriented | `search_web`, `query_database` |
| Graph variable | `lower_with_under` | `agent_graph`, `research_graph` |
| Builder variable | `lower_with_under` + `_builder` | `agent_builder`, `sub_builder` |
| Config dict | `lower_with_under` | `config`, `thread_config` |
| Node name (string) | `lower_with_under` | `"call_llm"`, `"tool_node"` |
| Subgraph | `lower_with_under` + descriptive | `research_subgraph`, `analyst_agent` |
| Context schema | `CapWords` + `Context` suffix | `AppContext`, `UserContext` |
| Checkpoint variable | `lower_with_under` | `checkpointer`, `memory_saver` |
| Store variable | `lower_with_under` | `store`, `memory_store` |
| Thread ID | descriptive string | `"user-123"`, `"session-abc"` |
| Stream mode | official constants only | `"values"`, `"updates"`, `"messages"`, `"custom"` |

### File Naming

| File | Convention | Example |
|------|-----------|---------|
| Graph definition | `graph.py` or descriptive | `graph.py`, `research_graph.py` |
| State schema | `state.py` | `state.py` |
| Node modules | action-oriented | `llm_call.py`, `tool_executor.py` |
| Tool modules | domain-oriented | `search.py`, `database.py` |
| Test files | `test_` prefix | `test_graph.py`, `test_nodes.py` |
| Config/constants | `config.py` | `config.py` |

---

## LANGGRAPH PLATFORM / DEPLOYMENT

### langgraph.json (Platform config)

```json
{
    "dependencies": ["."],
    "graphs": {
        "agent": "./src/my_agent/graph.py:graph"
    },
    "env": ".env",
    "store": {
        "index": {
            "embed": "openai:text-embedding-3-small",
            "dims": 1536,
            "fields": ["$"]
        }
    }
}
```

### LangGraph SDK Client

```python
"""Interact with a deployed LangGraph agent via SDK."""

from langgraph_sdk import get_client

client = get_client(url="http://localhost:2024")

# Create a thread
thread = await client.threads.create()

# Stream a run
async for chunk in client.runs.stream(
    thread_id=thread["thread_id"],
    assistant_id="agent",
    input={"messages": [{"role": "user", "content": "Hello"}]},
    stream_mode=["values", "messages"],
):
    print(chunk)
```

### Environment Variables

```bash
# Required for Claude-based agents
ANTHROPIC_API_KEY=sk-ant-...

# Required for OpenAI-based agents
OPENAI_API_KEY=sk-...

# LangSmith tracing (recommended)
LANGSMITH_API_KEY=lsv2_...
LANGSMITH_TRACING=true
LANGSMITH_PROJECT=my-agent

# Encryption (optional)
LANGGRAPH_AES_KEY=base64-encoded-key

# Database (production)
DATABASE_URL=postgresql://user:pass@host:5432/langgraph
```
