---
name: prompt-engineering
description: MUST USE when building LLM-powered applications with the Anthropic SDK or Claude API — prompt design, system prompts, tool use, structured output, prompt caching, batch API, multi-turn conversation management, and token optimization.
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: python
  framework: anthropic-sdk
  pattern: prompt-engineering
---

# Prompt Engineering — Anthropic SDK (Python)

> SDK version: `anthropic >= 0.102.0`
> Models: `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5`

---

## 1. System Prompt Design Principles

### Structure: Role → Constraints → Output Format

```python
import anthropic

client = anthropic.Anthropic()

SYSTEM_PROMPT = [
    {
        "type": "text",
        "text": """You are a senior code reviewer for a Python fintech codebase.

<constraints>
- Only review the diff provided; do not speculate about unseen code.
- Flag security issues as CRITICAL, style issues as MINOR.
- Never suggest changes that break backward compatibility.
</constraints>

<output_format>
Respond in JSON:
{
  "issues": [{"severity": "CRITICAL|MAJOR|MINOR", "line": int, "message": str}],
  "summary": str
}
</output_format>""",
        "cache_control": {"type": "ephemeral"},  # cache the system prompt
    }
]

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=2048,
    system=SYSTEM_PROMPT,
    messages=[{"role": "user", "content": "Review this diff:\n```diff\n...\n```"}],
)
```

### Design Checklist

| Principle | Example |
|-----------|---------|
| **Assign a role** | "You are a senior data engineer..." |
| **State constraints explicitly** | "Never output PII. Max 3 paragraphs." |
| **Specify output format** | JSON schema, XML tags, markdown |
| **Use XML delimiters** | `<context>`, `<instructions>`, `<examples>` |
| **Provide few-shot examples** | 2-3 input/output pairs inside `<examples>` |
| **Put long context first** | Documents before questions (cache-friendly) |

---

## 2. Prompt Caching Patterns

Prompt caching reduces latency by >2x and cost by up to 90% for repeated prefixes.

### Minimum Cacheable Tokens

| Model | Min Tokens |
|-------|-----------|
| Claude Opus 4.7 / 4.6 / 4.5 | 4,096 |
| Claude Sonnet 4.6 / 4.5 | 1,024 |
| Claude Haiku 4.5 | 4,096 |

### Pricing Multipliers

| Operation | Cost vs Base Input |
|-----------|-------------------|
| 5-min cache write | 1.25x |
| 1-hour cache write | 2x |
| Cache read (hit) | 0.1x |

### 2a. Automatic Caching (Recommended for Multi-Turn)

```python
# The SDK auto-places breakpoint on the last cacheable block.
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    cache_control={"type": "ephemeral"},  # single top-level flag
    system="You are a helpful coding assistant with deep Python expertise.",
    messages=[
        {"role": "user", "content": "<codebase>" + large_codebase + "</codebase>"},
        {"role": "assistant", "content": "I've reviewed the codebase. What would you like to know?"},
        {"role": "user", "content": "Find all SQL injection vulnerabilities."},
    ],
)
```

### 2b. Explicit Breakpoints (Fine-Grained Control)

Up to 4 breakpoints per request. Place on stable, long content.

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": LARGE_SYSTEM_PROMPT,       # ~5k tokens, stable
            "cache_control": {"type": "ephemeral"},  # breakpoint 1
        }
    ],
    tools=tools_with_cache,                    # breakpoint 2 on last tool
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "<document>" + doc_text + "</document>",
                    "cache_control": {"type": "ephemeral"},  # breakpoint 3
                },
                {"type": "text", "text": "Summarize the key findings."},
            ],
        }
    ],
)
```

### 2c. 1-Hour Cache TTL

Use when requests come >5 min apart but within the same hour.

```python
system = [
    {
        "type": "text",
        "text": LARGE_REFERENCE_DOC,
        "cache_control": {"type": "ephemeral", "ttl": "1h"},  # 2x write cost
    }
]
```

### 2d. Cache Pre-Warming

Eliminate cold-start latency by pre-warming before user traffic arrives.

```python
# Pre-warm (set max_tokens=0, costs only cache write)
client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=0,
    system=[
        {"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}},
    ],
    messages=[{"role": "user", "content": "warmup"}],
)
```

### 2e. Monitoring Cache Performance

```python
usage = response.usage
print(f"Cache write:  {usage.cache_creation_input_tokens}")
print(f"Cache read:   {usage.cache_read_input_tokens}")
print(f"Uncached:     {usage.input_tokens}")
# total = cache_creation + cache_read + input_tokens
```

---

## 3. Tool Use / Function Calling

### 3a. Defining Tools

```python
tools = [
    {
        "name": "get_stock_price",
        "description": "Get the current stock price for a given ticker symbol. Use when the user asks about stock prices or market data.",
        "strict": True,  # guarantees schema conformance
        "input_schema": {
            "type": "object",
            "properties": {
                "ticker": {
                    "type": "string",
                    "description": "Stock ticker symbol, e.g. 'AAPL'",
                },
                "currency": {
                    "type": "string",
                    "enum": ["USD", "EUR", "GBP"],
                    "description": "Currency for the price",
                },
            },
            "required": ["ticker"],
        },
    }
]
```

### 3b. The Agentic Tool-Use Loop

```python
import json

messages = [{"role": "user", "content": "What's AAPL stock price in EUR?"}]

while True:
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        tools=tools,
        cache_control={"type": "ephemeral"},
        messages=messages,
    )

    # If model is done, break
    if response.stop_reason == "end_turn":
        final_text = next(b.text for b in response.content if b.type == "text")
        print(final_text)
        break

    # Process tool calls
    tool_results = []
    for block in response.content:
        if block.type == "tool_use":
            result = execute_tool(block.name, block.input)  # your dispatch fn
            tool_results.append(
                {
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": json.dumps(result),
                }
            )

    # Append assistant turn + tool results
    messages.append({"role": "assistant", "content": response.content})
    messages.append({"role": "user", "content": tool_results})
```

### 3c. Controlling Tool Choice

```python
# Auto (default): model decides whether to call tools
tool_choice = {"type": "auto"}

# Force a specific tool (model MUST call it)
tool_choice = {"type": "tool", "name": "get_stock_price"}

# Force any tool (model must call at least one)
tool_choice = {"type": "any"}

# Disable tools for this turn
tool_choice = {"type": "none"}

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=tools,
    tool_choice=tool_choice,
    messages=messages,
)
```

### 3d. Caching Tool Definitions

```python
# Add cache_control to the LAST tool definition
tools_cached = [
    {"name": "tool_a", "description": "...", "input_schema": {...}},
    {"name": "tool_b", "description": "...", "input_schema": {...}},
    {
        "name": "tool_c",
        "description": "...",
        "input_schema": {...},
        "cache_control": {"type": "ephemeral"},  # caches all tools above too
    },
]
```

---

## 4. Structured Output

### 4a. JSON Mode via Tool Use (Most Reliable)

Force a tool call with a strict schema to guarantee valid JSON output.

```python
from pydantic import BaseModel


class SentimentResult(BaseModel):
    sentiment: str  # "positive" | "negative" | "neutral"
    confidence: float
    key_phrases: list[str]


extract_tool = {
    "name": "extract_sentiment",
    "description": "Extract sentiment analysis from the given text.",
    "strict": True,
    "input_schema": SentimentResult.model_json_schema(),
}

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=[extract_tool],
    tool_choice={"type": "tool", "name": "extract_sentiment"},
    messages=[{"role": "user", "content": f"Analyze sentiment: {text}"}],
)

# Parse the guaranteed-valid JSON
tool_block = next(b for b in response.content if b.type == "tool_use")
result = SentimentResult.model_validate(tool_block.input)
```

### 4b. XML Parsing Pattern

Use XML tags in prompts for structured sections that don't need strict JSON.

```python
SYSTEM = """Extract entities from the text. Wrap output in XML tags:
<entities>
  <person name="..." role="..."/>
  <organization name="..." />
  <location name="..." />
</entities>"""

import re
from xml.etree import ElementTree

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=SYSTEM,
    messages=[{"role": "user", "content": article_text}],
)

text = response.content[0].text
xml_match = re.search(r"<entities>.*?</entities>", text, re.DOTALL)
if xml_match:
    root = ElementTree.fromstring(xml_match.group())
    persons = [el.attrib for el in root.findall("person")]
```

### 4c. Prefilled Assistant Response

Guide the model to start output in a specific format.

```python
messages = [
    {"role": "user", "content": "List the top 3 Python web frameworks as JSON."},
    {"role": "assistant", "content": '[{"name": "'},  # prefill forces JSON array
]

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=512,
    messages=messages,
)
# Concatenate prefill + completion to get full JSON
full_json = '[{"name": "' + response.content[0].text
```

---

## 5. Multi-Turn Conversation Management

### 5a. Basic Context Window Management

```python
from anthropic import Anthropic

client = Anthropic()

def chat(conversation: list[dict], user_input: str, system: str) -> str:
    conversation.append({"role": "user", "content": user_input})

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        system=system,
        cache_control={"type": "ephemeral"},  # auto-cache growing context
        messages=conversation,
    )

    assistant_msg = response.content[0].text
    conversation.append({"role": "assistant", "content": assistant_msg})
    return assistant_msg
```

### 5b. Summarization for Long Conversations

```python
def maybe_summarize(conversation: list[dict], max_turns: int = 20) -> list[dict]:
    """Summarize older turns when conversation exceeds max_turns."""
    if len(conversation) <= max_turns:
        return conversation

    # Keep the last N turns intact
    keep = max_turns // 2
    old_turns = conversation[:-keep]
    recent_turns = conversation[-keep:]

    # Ask Claude to summarize the old turns
    summary_resp = client.messages.create(
        model="claude-haiku-4-5",  # cheap model for summarization
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": (
                    "Summarize this conversation history concisely, "
                    "preserving key facts and decisions:\n\n"
                    + format_turns(old_turns)
                ),
            }
        ],
    )

    summary = summary_resp.content[0].text
    return [
        {"role": "user", "content": f"<conversation_summary>{summary}</conversation_summary>"},
        {"role": "assistant", "content": "Understood, I have the context from our earlier conversation."},
        *recent_turns,
    ]
```

---

## 6. Token Optimization Techniques

### 6a. Prompt Compression

```python
# BAD: verbose prompt wastes tokens
bad = """
I would like you to please analyze the following text and provide me with
a comprehensive summary of the main points. Please make sure to include
all of the important details and key takeaways from the text.
"""

# GOOD: concise prompt, same result
good = "Summarize the key points from this text:"
```

### 6b. Selective Context Loading

```python
def build_context(query: str, documents: list[str], max_tokens: int = 8000) -> str:
    """Select only relevant documents to fit within budget."""
    # Use embeddings or keyword matching to rank relevance
    ranked = rank_by_relevance(query, documents)

    context_parts = []
    token_count = 0
    for doc in ranked:
        doc_tokens = count_tokens(doc)  # use anthropic.count_tokens or tiktoken
        if token_count + doc_tokens > max_tokens:
            break
        context_parts.append(doc)
        token_count += doc_tokens

    return "\n---\n".join(context_parts)
```

### 6c. Model Routing for Cost

```python
def route_model(task: str, input_tokens: int) -> str:
    """Pick the cheapest model that can handle the task."""
    if input_tokens < 500 and task in ("classification", "extraction", "yes_no"):
        return "claude-haiku-4-5"       # $1/MTok input
    elif task in ("code_review", "analysis", "creative"):
        return "claude-sonnet-4-6"      # $3/MTok input
    else:
        return "claude-opus-4-7"        # $5/MTok input
```

---

## 7. Batch API Patterns

50% cost reduction, up to 100k requests per batch, most complete within 1 hour.

### 7a. Creating a Batch

```python
batch = client.messages.batches.create(
    requests=[
        {
            "custom_id": f"item-{i}",
            "params": {
                "model": "claude-sonnet-4-6",
                "max_tokens": 1024,
                "cache_control": {"type": "ephemeral", "ttl": "1h"},  # 1h for batches
                "messages": [{"role": "user", "content": prompt}],
            },
        }
        for i, prompt in enumerate(prompts)
    ]
)
print(f"Batch ID: {batch.id}, Status: {batch.processing_status}")
```

### 7b. Polling and Retrieving Results

```python
import time

# Poll until complete
while True:
    batch = client.messages.batches.retrieve(batch.id)
    if batch.processing_status == "ended":
        break
    print(f"Status: {batch.processing_status} — "
          f"{batch.request_counts.succeeded}/{batch.request_counts.processing}")
    time.sleep(30)

# Stream results
for result in client.messages.batches.results(batch.id):
    if result.result.type == "succeeded":
        text = result.result.message.content[0].text
        print(f"{result.custom_id}: {text[:100]}")
    else:
        print(f"{result.custom_id}: FAILED — {result.result.error}")
```

### 7c. Batch with File Upload (JSONL)

```python
# For very large batches, upload a JSONL file
import json

with open("requests.jsonl", "w") as f:
    for i, prompt in enumerate(prompts):
        f.write(json.dumps({
            "custom_id": f"req-{i}",
            "params": {
                "model": "claude-sonnet-4-6",
                "max_tokens": 512,
                "messages": [{"role": "user", "content": prompt}],
            },
        }) + "\n")

# Create batch from file
with open("requests.jsonl", "rb") as f:
    batch = client.messages.batches.create_from_file(file=f)
```

---

## 8. Streaming Patterns

### 8a. Basic Text Streaming

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Explain quantum computing."}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)

# Access final message after stream ends
final = stream.get_final_message()
print(f"\nTokens used: {final.usage.input_tokens} in, {final.usage.output_tokens} out")
```

### 8b. Streaming with Tool Use

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=tools,
    messages=messages,
) as stream:
    for event in stream:
        if event.type == "content_block_start":
            if event.content_block.type == "tool_use":
                print(f"\nCalling tool: {event.content_block.name}")
        elif event.type == "content_block_delta":
            if event.delta.type == "text_delta":
                print(event.delta.text, end="", flush=True)
            elif event.delta.type == "input_json_delta":
                print(event.delta.partial_json, end="")  # tool input building
```

### 8c. Streaming with Extended Thinking

```python
with client.messages.stream(
    model="claude-sonnet-4-6",
    max_tokens=16000,
    thinking={"type": "enabled", "budget_tokens": 10000},
    messages=[{"role": "user", "content": "Prove that sqrt(2) is irrational."}],
) as stream:
    for event in stream:
        if event.type == "content_block_delta":
            if event.delta.type == "thinking_delta":
                print(f"[thinking] {event.delta.thinking}", end="")
            elif event.delta.type == "text_delta":
                print(event.delta.text, end="", flush=True)
```

---

## 9. Extended Thinking / Chain-of-Thought

### 9a. Basic Extended Thinking

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=16000,
    thinking={"type": "enabled", "budget_tokens": 10000},
    messages=[{"role": "user", "content": "Design a rate limiter for a distributed system."}],
)

for block in response.content:
    if block.type == "thinking":
        print(f"[Thinking]\n{block.thinking}\n")
    elif block.type == "text":
        print(f"[Response]\n{block.text}")
```

### 9b. Display Modes

```python
# Summarized thinking (default on Claude 4 models)
thinking={"type": "enabled", "budget_tokens": 10000, "display": "summarized"}

# Omitted thinking (faster TTFT, lower streaming overhead)
thinking={"type": "enabled", "budget_tokens": 10000, "display": "omitted"}
```

### 9c. Extended Thinking + Tool Use

Thinking blocks MUST be preserved when passing tool results back.

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=16000,
    thinking={"type": "enabled", "budget_tokens": 8000},
    tools=[weather_tool],
    messages=[{"role": "user", "content": "What's the weather in Tokyo?"}],
)

# Extract blocks
thinking_block = next((b for b in response.content if b.type == "thinking"), None)
tool_block = next((b for b in response.content if b.type == "tool_use"), None)

if tool_block:
    # MUST include thinking_block in assistant content
    continuation = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=16000,
        thinking={"type": "enabled", "budget_tokens": 8000},
        tools=[weather_tool],
        messages=[
            {"role": "user", "content": "What's the weather in Tokyo?"},
            {"role": "assistant", "content": [thinking_block, tool_block]},
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": tool_block.id,
                        "content": '{"temp": "22°C", "condition": "Partly cloudy"}',
                    }
                ],
            },
        ],
    )
```

### 9d. Constraints with Extended Thinking

- `tool_choice` must be `"auto"` or `"none"` (no forced tool use)
- `budget_tokens` must be < `max_tokens`
- Changing `budget_tokens` invalidates message cache (system cache survives)
- Claude Opus 4.7: use adaptive thinking instead of manual `type: "enabled"`

---

## 10. Error Handling

### 10a. Retries with Exponential Backoff

```python
from anthropic import (
    Anthropic,
    APIStatusError,
    RateLimitError,
    APITimeoutError,
    InternalServerError,
)
import time

client = Anthropic(max_retries=3)  # SDK auto-retries on 429/5xx

# For custom retry logic:
def call_with_retry(messages, max_retries=5):
    for attempt in range(max_retries):
        try:
            return client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=1024,
                messages=messages,
            )
        except RateLimitError as e:
            wait = min(2 ** attempt * 1.0, 60)
            print(f"Rate limited. Retrying in {wait}s...")
            time.sleep(wait)
        except InternalServerError:
            if attempt == max_retries - 1:
                raise
            time.sleep(2 ** attempt)
        except APITimeoutError:
            if attempt == max_retries - 1:
                raise
            time.sleep(1)
    raise RuntimeError("Max retries exceeded")
```

### 10b. Model Fallback

```python
FALLBACK_CHAIN = ["claude-sonnet-4-6", "claude-haiku-4-5"]

def call_with_fallback(messages, system=None):
    for model in FALLBACK_CHAIN:
        try:
            return client.messages.create(
                model=model,
                max_tokens=1024,
                system=system or [],
                messages=messages,
            )
        except (RateLimitError, InternalServerError) as e:
            print(f"{model} failed: {e}. Trying next model...")
            continue
    raise RuntimeError("All models failed")
```

### 10c. Handling Overloaded Responses

```python
response = client.messages.create(...)

if response.stop_reason == "max_tokens":
    # Response was truncated — request continuation or increase max_tokens
    messages.append({"role": "assistant", "content": response.content})
    messages.append({"role": "user", "content": "Continue."})
    continuation = client.messages.create(...)
```

---

## 11. Testing Prompts

### 11a. Eval Pattern with Assertions

```python
import pytest

EVAL_CASES = [
    {
        "input": "The product is amazing, I love it!",
        "expected_sentiment": "positive",
    },
    {
        "input": "Terrible experience, would not recommend.",
        "expected_sentiment": "negative",
    },
    {
        "input": "It arrived on Tuesday.",
        "expected_sentiment": "neutral",
    },
]


@pytest.mark.parametrize("case", EVAL_CASES, ids=[c["input"][:30] for c in EVAL_CASES])
def test_sentiment_extraction(case):
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=256,
        tools=[sentiment_tool],
        tool_choice={"type": "tool", "name": "extract_sentiment"},
        messages=[{"role": "user", "content": f"Analyze: {case['input']}"}],
    )
    tool_block = next(b for b in response.content if b.type == "tool_use")
    assert tool_block.input["sentiment"] == case["expected_sentiment"]
```

### 11b. A/B Testing Prompts

```python
import random

PROMPT_VARIANTS = {
    "concise": "Classify the sentiment as positive, negative, or neutral. One word only.",
    "detailed": "Analyze the sentiment. Respond with JSON: {sentiment, confidence, reasoning}.",
}


def ab_test(text: str, variant: str | None = None) -> dict:
    variant = variant or random.choice(list(PROMPT_VARIANTS.keys()))
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=256,
        messages=[{"role": "user", "content": f"{PROMPT_VARIANTS[variant]}\n\nText: {text}"}],
    )
    return {
        "variant": variant,
        "output": response.content[0].text,
        "tokens": response.usage.input_tokens + response.usage.output_tokens,
        "latency_ms": None,  # measure externally
    }
```

### 11c. LLM-as-Judge Evaluation

```python
JUDGE_PROMPT = """Rate the following AI response on a scale of 1-5 for:
- Accuracy (does it match the reference answer?)
- Completeness (does it cover all key points?)
- Conciseness (is it appropriately brief?)

<reference>{reference}</reference>
<response>{response}</response>

Output JSON: {{"accuracy": int, "completeness": int, "conciseness": int, "reasoning": str}}"""


def judge_response(response_text: str, reference: str) -> dict:
    import json

    result = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[
            {
                "role": "user",
                "content": JUDGE_PROMPT.format(reference=reference, response=response_text),
            }
        ],
    )
    return json.loads(result.content[0].text)
```

---

## 12. Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Caching volatile content | Timestamps/user IDs at the start invalidate cache | Put stable content (system, docs) first; volatile content last |
| Omitting `cache_control` | Pays full price on every repeated call | Always set `cache_control` for repeated system/tool/doc content |
| Forcing tool + thinking | `tool_choice: "tool"` is incompatible with extended thinking | Use `tool_choice: "auto"` with thinking |
| Giant single-turn prompts | Hits context limit, high cost, slow | Summarize history, load only relevant docs |
| Ignoring `stop_reason` | Missing truncated responses | Always check `stop_reason == "end_turn"` |
| Hardcoding model strings | Breaks on deprecation | Use constants or env vars for model names |
| No retry logic | Single 429 kills the pipeline | Use SDK `max_retries` or custom backoff |
| Prefill with long text | Wastes output tokens; model may not continue naturally | Keep prefill to a few tokens (e.g., `{"`) |
| Dropping thinking blocks | Breaks tool-use continuation with thinking | Always pass thinking blocks back in assistant content |
| `any` type in schemas | Model guesses types, causes parse errors | Use explicit types; add `strict: True` to tool defs |
| Ignoring batch API for evals | 2x cost for non-time-sensitive work | Use Batch API for evals, bulk processing |
| Cache breakpoint on changing block | Cache never hits | Put breakpoint on the last **stable** block |

---

## 13. Cost Optimization Quick Reference

| Technique | Savings | When to Use |
|---|---|---|
| **Prompt caching (5-min)** | Up to 90% on cached tokens | Repeated system prompts, tools, docs |
| **Prompt caching (1-hour)** | Up to 90% (2x write cost) | Less frequent but repeated calls |
| **Batch API** | 50% on all tokens | Evals, bulk processing, non-real-time |
| **Model routing** | 3-5x (Haiku vs Opus) | Simple tasks routed to cheaper models |
| **Prompt compression** | 20-50% fewer input tokens | Verbose instructions, redundant context |
| **Selective context** | Variable | RAG: load only relevant chunks |
| **Summarize history** | 60-80% on long convos | Multi-turn conversations >20 turns |
| **`display: "omitted"`** | Lower streaming overhead | Extended thinking in latency-sensitive apps |
| **`max_tokens` tuning** | Avoid wasted output | Set realistic limits per task |
| **Cache pre-warming** | Latency (not cost) | High-traffic system prompts |

### Cost Formula

```
total_cost = (
    cache_write_tokens * base_input_price * 1.25  # or 2.0 for 1h TTL
    + cache_read_tokens * base_input_price * 0.1
    + uncached_input_tokens * base_input_price
    + output_tokens * output_price
)
# Batch API: multiply all by 0.5
```

### Current Pricing (per MTok)

| Model | Input | Output | Batch Input | Batch Output |
|---|---|---|---|---|
| Claude Opus 4.7 | $5 | $25 | $2.50 | $12.50 |
| Claude Sonnet 4.6 | $3 | $15 | $1.50 | $7.50 |
| Claude Haiku 4.5 | $1 | $5 | $0.50 | $2.50 |
