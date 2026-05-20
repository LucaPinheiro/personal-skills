---
name: bedrock-python
description: MUST USE when writing, reviewing, or debugging Python code that interacts with **Amazon Bedrock** — covers the **Converse API** (primary), **ConverseStream**, **invoke_model**, **tool use / function calling**, **guardrails**, **multi-modal inputs** (documents, images), and **async inference** (video/image generation). Use this skill whenever the user mentions Bedrock, boto3 bedrock-runtime, foundation models on AWS, LLM inference with AWS, model invocation with Python, or building generative AI apps on AWS. Also triggers for prompts about Anthropic Claude on AWS, Amazon Nova, streaming LLM responses with boto3, or function calling with Bedrock models.
license: BSD-3-Clause
compatibility: opencode
metadata:
  language: python
  platform: aws
  service: bedrock
  sdk: boto3
  pattern: generative-ai-inference
---

# AWS Bedrock Python — Distinguished AI Engineer's Playbook

You are a **distinguished AI engineer** writing or reviewing Python code that drives **Amazon Bedrock**. Your job is to ship inference code that is **consistent across models, handles streaming gracefully, retries on transient failures, and never leaks credentials**.

Bedrock provides two primary Python SDK surfaces via `boto3`:
- **`bedrock-runtime`** — for invoking models (converse, streaming, async)
- **`bedrock-agent-runtime`** — for RAG with Knowledge Bases and Agents

This skill focuses on the **runtime** surface. For agent/orchestration patterns, see separate skills.

---

## Golden Rule: Converse API First

**Always default to `converse` or `converse_stream`.** The Converse API provides a unified message format that works across all Bedrock models that support messages (Claude, Nova, Llama, Mistral, Cohere, DeepSeek). This means you write code once and switch models by changing the `modelId`.

Only reach for `invoke_model` when:
- The model does **not** support the Converse API (e.g., some imported models, older models)
- You need the **native request/response format** for a specific capability not exposed via Converse (e.g., image generation with Nova Canvas, video with Nova Reel)
- You are using **Amazon Titan Embeddings** (use `invoke_model` with the native payload)

---

## 1. Client Setup

```python
import boto3
from botocore.exceptions import ClientError

# Preferred: let boto3 resolve credentials from the environment
# (IAM role, SSO, env vars, ~/.aws/credentials — never hardcode keys)
bedrock_runtime = boto3.client("bedrock-runtime", region_name="us-east-1")
```

**Credential resolution** follows the standard boto3 chain: env vars → shared config → IAM role (EC2/ECS/Lambda) → SSO. For long-running applications (e.g., streaming), increase the read timeout to avoid socket timeouts on slow model responses:

```python
from botocore.config import Config

config = Config(read_timeout=300)  # 5 minutes for large responses
bedrock_runtime = boto3.client(
    "bedrock-runtime",
    region_name="us-east-1",
    config=config,
)
```

---

## 2. Converse API — Synchronous

```python
def generate_text(bedrock_runtime, model_id, prompt, system_prompt=None):
    """
    Send a single-turn message to a Bedrock model using the Converse API.

    Args:
        bedrock_runtime: boto3 bedrock-runtime client
        model_id: Bedrock model ID (e.g., "anthropic.claude-3-sonnet-20240229-v1:0")
        prompt: User message string
        system_prompt: Optional system instructions string

    Returns:
        Tuple of (response_text, usage_dict)
    """
    messages = [
        {
            "role": "user",
            "content": [{"text": prompt}],
        }
    ]

    kwargs = {
        "modelId": model_id,
        "messages": messages,
        "inferenceConfig": {
            "maxTokens": 2048,
            "temperature": 0.7,
            "topP": 0.9,
        },
    }

    if system_prompt:
        kwargs["system"] = [{"text": system_prompt}]

    try:
        response = bedrock_runtime.converse(**kwargs)
    except ClientError as e:
        raise RuntimeError(f"Bedrock converse failed: {e}") from e

    output_message = response["output"]["message"]
    text = output_message["content"][0]["text"]
    usage = response["usage"]

    return text, usage
```

### Multi-turn conversation

Pass the full conversation history in the `messages` array. The model has no memory — you must append each exchange:

```python
conversation = [
    {"role": "user", "content": [{"text": "What is Python?"}]},
    {"role": "assistant", "content": [{"text": "Python is a programming language..."}]},
    {"role": "user", "content": [{"text": "What are its main uses?"}]},
]

response = bedrock_runtime.converse(
    modelId=model_id,
    messages=conversation,
    inferenceConfig={"maxTokens": 1024, "temperature": 0.5},
)
```

### Model-specific parameters

Pass provider-specific parameters via `additionalModelRequestFields`:

```python
response = bedrock_runtime.converse(
    modelId="anthropic.claude-3-sonnet-20240229-v1:0",
    messages=messages,
    inferenceConfig={"temperature": 0.5},
    additionalModelRequestFields={"top_k": 200},
)
```

---

## 3. ConverseStream — Real-time Streaming

Use `converse_stream` for interactive UIs or when you want to display output as it generates:

```python
def stream_text(bedrock_runtime, model_id, prompt):
    """
    Stream a model response in real-time.

    Yields text chunks as they arrive.
    """
    messages = [
        {"role": "user", "content": [{"text": prompt}]},
    ]

    try:
        response = bedrock_runtime.converse_stream(
            modelId=model_id,
            messages=messages,
            inferenceConfig={"maxTokens": 2048, "temperature": 0.7},
        )
    except ClientError as e:
        raise RuntimeError(f"Bedrock stream failed: {e}") from e

    stream = response.get("stream")
    if not stream:
        return

    for event in stream:
        if "contentBlockDelta" in event:
            chunk = event["contentBlockDelta"]
            text = chunk["delta"].get("text", "")
            if text:
                yield text
        elif "metadata" in event:
            # Final event contains usage metadata
            usage = event["metadata"].get("usage", {})
            # Log or return usage metrics
```

**Important:** The stream is an iterator over events. Always check the event type before accessing fields — different events carry different payloads (`contentBlockDelta`, `contentBlockStart`, `messageStart`, `messageStop`, `metadata`).

---

## 4. Tool Use / Function Calling

Bedrock Converse API supports tool use across Claude, Nova, and Cohere models. Define tools as JSON Schema specifications:

```python
TOOL_SPEC = {
    "toolSpec": {
        "name": "get_weather",
        "description": "Get current weather for a location",
        "inputSchema": {
            "json": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "City and country, e.g. 'Sao Paulo, BR'",
                    },
                    "unit": {
                        "type": "string",
                        "enum": ["celsius", "fahrenheit"],
                    },
                },
                "required": ["location"],
            }
        },
    }
}


def call_tool(tool_name, tool_input):
    """Invoke the actual tool implementation."""
    if tool_name == "get_weather":
        # ... call weather API
        return {"temperature": 28, "condition": "sunny"}
    raise ValueError(f"Unknown tool: {tool_name}")


def converse_with_tools(bedrock_runtime, model_id, user_message, max_iterations=5):
    """
    Run a conversation that may involve tool use.

    Returns the final assistant response text.
    """
    messages = [
        {"role": "user", "content": [{"text": user_message}]},
    ]

    tool_config = {"tools": [TOOL_SPEC]}

    for _ in range(max_iterations):
        response = bedrock_runtime.converse(
            modelId=model_id,
            messages=messages,
            toolConfig=tool_config,
            inferenceConfig={"maxTokens": 2048, "temperature": 0.5},
        )

        output_message = response["output"]["message"]
        messages.append(output_message)

        stop_reason = response.get("stopReason")

        if stop_reason == "end_turn":
            # Model provided final text response
            for block in output_message["content"]:
                if "text" in block:
                    return block["text"]
            return ""

        elif stop_reason == "tool_use":
            # Model requested tool invocations
            tool_results = []

            for block in output_message["content"]:
                if "toolUse" in block:
                    tool_use = block["toolUse"]
                    result = call_tool(tool_use["name"], tool_use["input"])
                    tool_results.append({
                        "toolResult": {
                            "toolUseId": tool_use["toolUseId"],
                            "content": [{"json": result}],
                        }
                    })

            # Send tool results back as a user message
            messages.append({"role": "user", "content": tool_results})

        else:
            # stop_reason: max_tokens, stop_sequence, content_filtered
            break

    return "Maximum iterations reached without a final response."
```

**Key rules for tool use:**
- Always include the `toolUseId` in the `toolResult` — the model matches results to requests by this ID
- Tool results are sent as a **user** message role
- Guard against infinite loops with a `max_iterations` cap
- Handle tool errors gracefully: return `{"error": "..."}` in the tool result content instead of raising exceptions

---

## 5. Guardrails

Apply guardrails to filter harmful content:

```python
response = bedrock_runtime.converse(
    modelId=model_id,
    messages=messages,
    guardrailConfig={
        "guardrailIdentifier": "my-guardrail-id",
        "guardrailVersion": "1",  # or "DRAFT"
        "trace": "enabled",  # or "disabled"
    },
)
```

To apply a guardrail to a **specific message** rather than the entire conversation, wrap that message's content in a `guardContent` block:

```python
messages = [
    {
        "role": "user",
        "content": [
            {"guardContent": {"text": {"text": "sensitive prompt here"}}},
        ],
    }
]
```

---

## 6. Multi-modal Inputs

### Images

Supported by Claude 3 and Amazon Nova models. Up to 20 images per request:

```python
import base64

with open("image.png", "rb") as f:
    image_bytes = f.read()

messages = [
    {
        "role": "user",
        "content": [
            {"text": "Describe this image"},
            {
                "image": {
                    "format": "png",  # png, jpeg, gif, webp
                    "source": {"bytes": image_bytes},
                }
            },
        ],
    }
]
```

### Documents

Supported by Amazon Nova and Claude 3 models. Up to 5 documents per request:

```python
with open("report.pdf", "rb") as f:
    doc_bytes = f.read()

messages = [
    {
        "role": "user",
        "content": [
            {"text": "Summarize this document"},
            {
                "document": {
                    "format": "pdf",  # pdf, doc, docx, xls, xlsx, csv, txt, md, html
                    "name": "Q4_Report",
                    "source": {"bytes": doc_bytes},
                }
            },
        ],
    }
]
```

**Limits:** Each image ≤ 3.75 MB, dimensions ≤ 8000x8000 px. Each document ≤ 4.5 MB.

---

## 7. invoke_model — When You Must

For capabilities not exposed through Converse (image generation, embeddings, older models):

```python
import json

# Example: Amazon Titan Embeddings
request_body = {"inputText": "Hello world"}

response = bedrock_runtime.invoke_model(
    modelId="amazon.titan-embed-text-v2:0",
    body=json.dumps(request_body),
    contentType="application/json",
    accept="application/json",
)

response_body = json.loads(response["body"].read())
embedding = response_body["embedding"]
```

**invoke_model requires provider-specific payload formats.** Each model family has its own request/response schema. Prefer Converse for text generation to avoid this complexity.

---

## 8. Async Inference — Video and Image Generation

Amazon Nova Reel (video) uses asynchronous invocation:

```python
def generate_video(bedrock_runtime, prompt, output_s3_uri):
    """
    Start an async video generation job with Nova Reel.

    Returns the invocation ARN to poll for completion.
    """
    import random

    model_input = {
        "taskType": "TEXT_VIDEO",
        "textToVideoParams": {"text": prompt},
        "videoGenerationConfig": {
            "fps": 24,
            "durationSeconds": 6,
            "dimension": "1280x720",
            "seed": random.randint(0, 2147483646),
        },
    }

    output_config = {"s3OutputDataConfig": {"s3Uri": output_s3_uri}}

    response = bedrock_runtime.start_async_invoke(
        modelId="amazon.nova-reel-v1:0",
        modelInput=model_input,
        outputDataConfig=output_config,
    )

    return response["invocationArn"]


def poll_video_status(bedrock_runtime, invocation_arn):
    """Poll until the async job completes or fails."""
    while True:
        job = bedrock_runtime.get_async_invoke(invocationArn=invocation_arn)
        status = job["status"]

        if status == "Completed":
            return job["outputDataConfig"]["s3OutputDataConfig"]["s3Uri"]
        elif status == "Failed":
            raise RuntimeError(f"Video generation failed: {job.get('failureMessage')}")

        time.sleep(15)
```

---

## 9. Error Handling & Retries

Handle Bedrock-specific exceptions with `botocore.exceptions.ClientError`:

```python
from botocore.exceptions import ClientError

ERROR_HANDLERS = {
    "ThrottlingException": lambda e: ("retry", "Rate limited — backoff and retry"),
    "ModelNotReadyException": lambda e: ("retry", "Model still loading — retry shortly"),
    "ModelTimeoutException": lambda e: ("fail", "Model request timed out"),
    "ValidationException": lambda e: ("fail", f"Invalid request: {e}"),
    "AccessDeniedException": lambda e: ("fail", "IAM permissions missing for bedrock:InvokeModel"),
    "ResourceNotFoundException": lambda e: ("fail", "Model ID or guardrail not found"),
}


def invoke_with_retry(bedrock_runtime, **kwargs):
    import time

    max_retries = 3
    base_delay = 1.0

    for attempt in range(max_retries):
        try:
            return bedrock_runtime.converse(**kwargs)
        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            action, message = ERROR_HANDLERS.get(
                error_code, ("fail", f"Unexpected error: {e}")
            )

            if action == "fail" or attempt == max_retries - 1:
                raise RuntimeError(message) from e

            delay = base_delay * (2 ** attempt)
            time.sleep(delay)
```

**boto3 already retries `ThrottlingException` by default** with exponential backoff. The custom retry above is for when you need more control or want to surface user-friendly messages.

---

## 10. Common Model IDs

Always use the full model ID including version suffix:

| Model Family | Model ID |
|-------------|----------|
| Claude 3 Opus | `anthropic.claude-3-opus-20240229-v1:0` |
| Claude 3.5 Sonnet | `anthropic.claude-3-5-sonnet-20241022-v2:0` |
| Claude 3.5 Haiku | `anthropic.claude-3-5-haiku-20241022-v1:0` |
| Claude 3 Haiku | `anthropic.claude-3-haiku-20240307-v1:0` |
| Amazon Nova Micro | `amazon.nova-micro-v1:0` |
| Amazon Nova Lite | `amazon.nova-lite-v1:0` |
| Amazon Nova Pro | `amazon.nova-pro-v1:0` |
| Amazon Nova Premier | `amazon.nova-premier-v1:0` |
| Amazon Nova Canvas | `amazon.nova-canvas-v1:0` |
| Amazon Nova Reel | `amazon.nova-reel-v1:0` |
| Meta Llama 3 | `meta.llama3-70b-instruct-v1:0` |
| Mistral Large | `mistral.mistral-large-2402-v1:0` |
| Cohere Command R+ | `cohere.command-r-plus-v1:0` |
| DeepSeek R1 | `deepseek.r1-v1:0` |
| Titan Embed Text v2 | `amazon.titan-embed-text-v2:0` |

**Cross-region inference:** Prefix the model ID with the region, e.g., `us.anthropic.claude-3-sonnet-20240229-v1:0`.

---

## 11. Non-negotiables

1. **Never hardcode AWS credentials.** Use IAM roles, SSO, or environment variables. boto3 resolves them automatically.
2. **Prefer Converse over invoke_model** for all text/chat use cases. Converse abstracts provider-specific formats.
3. **Always handle `ClientError`.** Bedrock can throttle, timeout, or reject requests. Never let raw boto3 exceptions bubble to users without context.
4. **Cap tool-use recursion.** Models can get stuck in tool loops. Always set `max_iterations`.
5. **Check `stopReason`.** After `converse`, inspect `response["stopReason"]` — `end_turn`, `tool_use`, `max_tokens`, `stop_sequence`, or `content_filtered` each require different handling.
6. **Log token usage.** `response["usage"]` contains `inputTokens`, `outputTokens`, and `totalTokens`. Log these for cost tracking and debugging.
7. **Use streaming for UX.** In interactive applications, always use `converse_stream` instead of buffering the full response.
8. **Size-check multi-modal inputs.** Images > 3.75 MB or documents > 4.5 MB will fail with `ValidationException`.
9. **Use guardrails for production.** Any user-facing application should apply a guardrail to filter harmful outputs.
10. **Set appropriate timeouts.** Default boto3 read timeout is 60s. Increase to 300s+ for large context windows or slow models.

---

## Reference Links

- [Converse API docs](https://docs.aws.amazon.com/bedrock/latest/userguide/conversation-inference.html)
- [Converse API boto3 reference](https://docs.aws.amazon.com/boto3/latest/reference/services/bedrock-runtime/client/converse.html)
- [Tool use guide](https://docs.aws.amazon.com/bedrock/latest/userguide/tool-use.html)
- [Guardrails guide](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
- [AWS Code Examples — Bedrock Runtime](https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/bedrock-runtime)
