## Stitch Chat

> Status note: normative, unimplemented

Stitch Chat is a desktop app for interacting with AI agents, multimodal chatbots, and human users alike. Integrations may include OpenAI-compatible model response servers (OpenAI, Anthropic, OpenRouter, etc), local model servers (Ollama, LM Studio, etc), and coding agent runtimes that include built-in prompting and orchestration (Cursor, Claude Code, Codex, Antigravity, DS Harness, OpenCode, Aider, Meta Muse). We interface with these servers and runtimes alike via a local bridge that normalizes their various formats and response mechanisms to a universal interface, meaning the architecture extends to integrate with future models and orchestration harnesses, regardless of their invocation mechanism. Our cloud backend facilitates human participation in the same spaces. Stitch aims to bring together local AI, cloud-based models, and collaboration with human beings.

You can talk to local models, coding agents, or cloud model response providers (via the local bridge) without authenticating with your Stitch account, but authenticating enables human messaging, access to Stitch cloud bots, and message sync with the web app.

Run with `flutter run` to develop.

To integrate a model (cloud or local), developers implement or utilize an existing **adapter** (if one exists, the bot may simply be registered). One adapter plugs one model response runtime into Stitch.

### Data Model

Stitch utilizes a generic data model for tracking conversations and messages. Instead of centering the data model on the thread (a linear string of messages), we center the message object itself and support connections between them for reply chaining and context engineering. The fundamental data model is that of the message.

There are two kinds of directed links between messages: **reply**-like and **stitch**-like. Reply links are only (optionally) generated on message creation, while stitch links may be arbitrarily added. Both may be followed for context curation. A linearly connected subset of messages acts as the rendered thread and context object.

This enables (potentially automatic) A/B iteration on prompts, models and context windows. You may reply to the same message multiple times or prompt multiple responses to the same message to fork a thread (multiple bots can be tagged on a single message). Vary the message content, the preceding context, or the model you invoke independently, then compare responses side by side or programatically. We also version control the environment on the message node basis for comparing results between coding runtimes. 


### Adapter Contract

An adapter (along with its runtime) transforms one Stitch message (the initial bot invocation) and its preceding context into one or more asynchronous response messages. Bot invokations are processed in parallel, so one bot may process multiple messages at once. 

Each adapter implementation may accept the following inputs:

* Model and version, e.g.
   - `@claude-code:sonnet-5.6 ...` → Claude Code runtime + model (required)
   - `@cursor:gpt-sol-5.6` → Cursor runtime + model
   - `@chatgpt:gpt-sol-5.6` → OpenAI runtime, OpenAI endpoint + model^
* A cwd (where applicable)
* One or more MCP server URLs (+ auth)

And to emit:

* One or more asynchronous response messages (potentially containing multipart media or function invocations and responses)
* Token usage by in/out and pricing, for cost calculation

Adapters have control over message contents and reply-chaining, which is unrestricted, not single response, subject to the constraint that a bot may reply only to nodes it has seen this invocation: any in the context chain, the trigger, plus any of its own prior emissions once ack'd. 

^ ChatGPT could be invoked via OpenAI, OpenRouter, or coding orchestration harnesses. Typically one popular model will have a canonical user ID to a simple response endpoint (OpenRouter or provider-hosted), and agentic coding harnesses are invoked as their own bot users, with version deciding the model, but the model/version paradigm is flexible: multiple versions of chatgpt can be configured per model, e.g. `@chatgpt:openrouter` vs `@chatgpt:openai`. Thinking effort and other model parameters fold into model versioning too, e.g. via `@claude-code:sonnet-5.6-high`.


### Architecture

Some agentic coding harnesses like Cursor and Claude Code expose Python SDKs, while others like DS Harness runs one-shot headless with `dsh`. OpenAI, Anthropic, and other model providers expose remote REST APIs, and local harnesses like Ollama and OpenCode host them on your machine. Other local runtimes respond via SSE, WS or JSON-RPC over `stdio`, and others utilize none of these mechanisms. To unify these various regimes for model invocation, we use an IPC pattern to communicate between our Flutter application and a lightweight Python bridge server. The bridge adapts Stitch message chains to runtime-specific parameterizations and invokation mechanisms via an adapter implementaion. Invocations execute independently and emit response message nodes asynchronously, allowing multiple invocations (of one or many bots) to execute concurrently. Adapter implementations should be reentrant at the invocation boundary. This is natural in the HTTP regime, but for a stateful SDK may require e.g. instantiating a per-invocation client/session internally to the adapter implementation. An invocation may consist of one or many commands after it passes through an adapter.

```
Dart/Flutter
    ↓    ↑
Python server
    ↓    ↑
Adapter implementation
    ↓    ↑
Response runtime
```

A `runtime` is anything an adapter can invoke to produce model or agent output. It may be a remote service, local server, SDK, library, executable, protocol-speaking process, etc. Because of that flexibility, a bot is not limited to call-and-response (although practically, it will often implement this pattern). It may prioritize one of multiple messages arriving in quick succession, or respond to the original user message and context by logging its reasoning in a fork, comment on messages in the context, chain multiple messages to the users sequentially, etc.


#### Ownership

* **Dart owns** — persistence (local and cloud, abstract repo implementations), environment lifecycle (materialization and teardown), snapshot creation, message identity, and the mapping from message nodes to environment state.
* **Python bridge owns** — bot registry, adapter invocation, response normalization, process supervision, and `reply_to` validation.
* **Adapter owns** — Stitch message + context → runtime call, and runtime output → Stitch nodes.
* **Runtime owns** — response generation and emission, model sandboxing, permissions, and capabilities.

#### How Adapters Partition Bots

A single runtime adapter may facilitate access to many models (e.g. an OpenAI compatible REST runtime). Adapters partitions registered bot models neither by their execution environment (local vs cloud, in- vs out-of-process, etc) nor their provider (OpenAI, Anthropic, etc) _necessarily_, but by the **means of invocation** and **parameterization**. If two methods share both their means of invocation _and_ how Stitch message parameters map to that invocation, they should share a runtime adapter. Take for example three common invocation regimes:

* **SDK regime** — generally one adapter per SDK, since each has its own session/invocation model: `ClaudeCodeAdapter`, `CursorAdapter`, `AntigravityAdapter`
* **API regime** — `OpenAICompatibleAdapter` is one concrete class covering OpenRouter (cloud), Ollama (local), and any future provider speaking OpenAI's chat/completions schema
* **Subprocess regime** — similar to the SDK regime, insofar as each subprocess invocation or commandline interface maps Stitch fields differently to functionality

Within a regime, adapters may share a common base class or utilities (e.g. for spawn, capture, kill, request, response, etc) but will not necessarily share an adapter implementation just because they look similar, and regimes that look different at a glance (local vs cloud HTTP) may share an adapter.

#### Layer Interfaces

Each layer (Dart, bridge, adapter, runtime) communicates with its neighbors via specific protocols and schemas.

1. **Dart <--> bridge** - we multiplex a single websocket connection across conversations and models using two envelopes: one for messages / invocations, and one for cues like typing, awaiting-approval, etc.
2. **bridge <--> adapter** - the abstract adapter class defines the invocation contract (roughly a Stitch message + context, bot recipient, environment, and capabilities), and emits response messages asynchronously. The bridge uses a bot registry to map bot IDs to adapters.
3. **adapter <--> runtime** - the adapter implementation decides how to invoke its particular model runtime, and with what parameters. The glue and duct tape goes here if needed.

The adapter and runtime together decide *how to respond* — the rest is product, transport, validation, and enforcement. 

### Filesystem Snapshots

> A filesystem-backed invocation executes against a materialized environment derived from the parent message’s environment state. Stitch snapshots resulting state and associates it with emitted message nodes.

Stitch versions your working directory recursively (up to a practical size constraint) when you pass it to a model as your `cwd` (generally optional) for the purposes of rollback and branch comparison. We do not sandbox the environment based on the `cwd`. Model sandboxing and permissioning (confinement) belongs to the runtime. Snapshot refs are associated directly with message nodes - "what the cwd looked like at this message". One nuance here: behavior can exceed cwd scope, via shell commands, shared config modifications, external tooling, etc. The snapshot is technically best-effort and practical. Materialized directories are ephemeral realizations of persistent snapshot state for model invocation context. Snapshots are authoritative; working directories are caches. Simplifies cleanup, lazy materialization, branching, and rematerialization. The user's actual "working directory" they see on their filesystem and test on is independent of either of these and automatically fast-forwarded to to the most recent response with UI on the node for clarity. 

Snapshots use Git’s object database as a content-addressed store, but Stitch does not use Git as a working-copy manager. Stitch walks the environment itself, hashes file contents, constructs tree objects, and records the resulting commit/tree identifier. This avoids `.gitignore`, nested-repository gitlinks, and mutation of the user’s branch or staging area. Untracked files are generally included subject to explicit space-policy exclusions; nested repositories are treated as ordinary filesystem content for snapshot purposes; actual repository HEADs are recorded separately as metadata/indexing; deduplication comes from Git object identity.

Materialization and snapshotting are lazy and content-addressed. Concurrent invocations require separate working directories. Large generated trees remain the principal practical cost; exclusions such as `node_modules`, `.venv`, and build outputs are therefore a storage policy rather than `.gitignore` semantics. We accept non-trivial snapshot materialization and persistent timing as negligible next to model response times, and the practical size constraint that caps this functionality reflects that principle. 

### Thanks for reading
