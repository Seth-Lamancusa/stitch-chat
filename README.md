## Stitch Chat

> Status note: normative, unimplemented

Stitch Chat is a desktop app for interacting with AI agents, multimodal chatbots, and human users alike. Integrations may include OpenAI-compatible model response servers (OpenAI, Anthropic, OpenRouter, etc), local model servers (Ollama, LM Studio, etc), and coding agent runtimes that include built-in prompting and orchestration (Cursor, Claude Code, Codex, Antigravity, DS Harness, OpenCode, Aider, Meta Muse, etc). We interface with these servers and runtimes alike via a local bridge that normalizes their various formats and response mechanisms to a universal interface, meaning the architecture extends to integrate with future models and orchestration harnesses, regardless of their invocation mechanism. Our cloud backend facilitates human participation in the same spaces. Stitch aims to bring together local AI, cloud-based models, and collaboration with human beings.

You can talk to local models, coding agents, or cloud model response providers (via the local bridge) without authenticating with your Stitch account, but authenticating enables human messaging, access to Stitch cloud bots, and message sync with the web app.

Run with `flutter run` to develop.

To integrate a model (cloud or local), developers implement or utilize an existing **adapter** (if one exists, the bot may simply be registered). An adapter plugs a model response runtime (which may support multiple bots, see below) into Stitch.


### Data Model

Stitch utilizes a generic data model for tracking conversations and messages. Instead of centering the data model on the thread (a linear string of messages), we center the message object itself and support connections between them for reply chaining and context engineering. The fundamental data model is that of the message.

There are two kinds of directed links between messages: **reply**-like and **stitch**-like. Reply links are only (optionally) generated on message creation, while stitch links may be arbitrarily added. Both may be followed for context curation. A linearly connected subset of messages acts as the rendered thread and context object. This enables two things: efficient, dynamic context management for token usage optimization or response quality, and iteration on prompts, models, and context windows as isolated variables. 

Forking a thread enables you to use only the context up to a certain point in the conversation (specification, exploration, etc) but not subsequent messages. This is useful when a followup question or quick bug fix benefits from your existing context window, but itself is irrelevant to subsequent work. Stitching the tail of a conversation to another is a natural way to plug subagent work results like codebase exploration into your thread. Claude Code's Agent Skills frontmatter spec does this with its "fork" field; Stitching is a more flexible, general way of plugging part of one conversation into the context of another.

You may reply to the same message multiple times or prompt multiple responses to a message to fork a thread (multiple bots can be tagged on a single message). Vary the message content, the preceding context, or the model you invoke independently, then compare responses side by side visually, or programatically. Note, since agents execute in the live `cwd`, you are responsible for isolating your experimental environments. For scientific purposes, the Stitch data model assumes (and therefore does not enforce) independence between invocation consequences, and that model responses capture experiment results completely.


### Adapter Contract

An adapter (along with its runtime) transforms one Stitch message (the initial bot invocation) and its preceding context into one or more asynchronous response messages. Bot invokations are processed in parallel, so one bot may process multiple messages at once. 

Each adapter implementation may accept the following inputs:

* Model and version, e.g.
   - `@claude-code:sonnet-5.6 ...` → Claude Code runtime + model (required)
   - `@cursor:gpt-sol-5.6` → Cursor runtime + model
   - `@chatgpt:gpt-sol-5.6` → OpenAI runtime, OpenAI endpoint + model^
* Metadata:
   - A cwd (where applicable)
   - One or more MCP server URLs (+ auth)

And to emit:

* One or more asynchronous response messages (potentially containing multipart media or function invocations and responses)
* Token usage by in/out and pricing, for cost calculation

Adapters have control over message contents and reply-chaining, which is unrestricted, not single response, subject to the constraint that a bot may reply only to nodes it has seen this invocation: any in the context chain, the trigger, plus any of its own prior emissions once ack'd. We stream traditional "content parts" (text blocks, function invocations/results) as individual (potentially chained) messages, not individual tokens. We do not collect or persist thinking/reasoning blocks as a special case, but possibly as a typed Stitch message that an adapter/runtime decides to broadcast.

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

The Python server provides a bot manifest from a `BotRegistry`, advertising capabilities and availability. Dart doesn't know about adapters or runtimes.

#### Ownership

* **Dart owns** — persistence (local and cloud, abstract data repo implementations), message identity.
* **Python bridge owns** — bot registry, adapter invocation, response normalization, process supervision, `reply_to` validation.
* **Adapter owns** — Stitch message + context → runtime call, and runtime output → Stitch nodes.
* **Runtime owns** — response generation and emission, model sandboxing, permissions, capabilities.

#### How Adapters Partition Bots

A single runtime adapter may facilitate access to many models (e.g. an OpenAI compatible REST runtime). Adapters partitions registered bot models neither by their execution environment (local vs cloud, in- vs out-of-process, etc) nor their provider (OpenAI, Anthropic, etc) _necessarily_, but by the **means of invocation** and **parameterization**. If two methods share both their means of invocation _and_ how Stitch message parameters map to that invocation, they should share a runtime adapter. Take for example three common invocation regimes:

* **SDK regime** — generally one adapter per SDK, since each has its own session/invocation model: `ClaudeCodeAdapter`, `CursorAdapter`, `AntigravityAdapter`
* **API regime** — `OpenAICompatibleAdapter` is one concrete class covering OpenRouter (cloud), Ollama (local), and any future provider speaking OpenAI's chat/completions schema
* **Subprocess regime** — similar to the SDK regime, insofar as each subprocess invocation or commandline interface maps Stitch fields differently to functionality

Within a regime, adapters may share a common base class or utilities (e.g. for spawn, capture, kill, request, response, etc) but will not necessarily share an adapter implementation just because they look similar, and regimes that look different at a glance (local vs cloud HTTP) may share an adapter.

#### Layer Interfaces

Each layer (Dart, bridge, adapter, runtime) communicates with its neighbors via specific protocols and schemas.

1. **Dart <--> bridge** - we multiplex a single websocket connection across conversations and models using two envelopes: one for messages / invocations, and one for cues like typing, awaiting-approval, etc.
2. **bridge <--> adapter** - the abstract adapter class defines the invocation contract (roughly a Stitch message + context, bot recipient, git hash, and capabilities), and emits response messages asynchronously. The bridge uses a bot registry to map bot IDs to adapters.
3. **adapter <--> runtime** - the adapter implementation decides how to invoke its particular model runtime, and with what parameters. The glue and duct tape goes here if needed.

The adapter and runtime together decide *how to respond* — the rest is product, transport, validation, and enforcement. 

#### Cloud-based Interaction
- Bridge handles responses in-process with arbitrarily finite response time; human responses aren't instantaneous, and conceptually neither are model responses.
- Each user on the platform may be a bot or a human, local or cloud-backed, able to access external tools (including through MCP servers registered with Stitch). TBD: good UI representations for cloud vs. locally _registered_, plus common cross-cutting cases (cloud-backed response generation, local response gen + external tooling, fully local, simply human, etc) and a coherent, comprehensive definition on the user level (to be advertised by the bot registry for bots registered locally, or otherwise inferred from cloud user attributes including `is-bot`).
- Before authenticating: interact with local models, access _public_ cloud messages from cloud users.
- After authenticating: access private messages, post to other cloud users, sync local-bot interactions with cloud backend.

#### Error Handling
- All user-facing errors route through a single `NotificationService` (`lib/core/notifications/`) rather than ad-hoc `errorMessage` state on ViewModels.
- Toast (non-blocking, default) — scoped to one failed operation, rest of app stays usable, auto-dismisses.
- Blocking banner (`blocking: true`) — reserved for app-unusable errors (e.g. bridge connection down), persists until dismissed. Use sparingly — default-blocking trains users to reflexively dismiss.
- Every notification gets a copy button for free (paste error text into a bug report without transcribing).
- `NotificationOverlay` renders whatever `NotificationService` holds, wraps app root — new screens/ViewModels just inject the service, no bespoke error UI.


### Tips
- Prefer new files for new logic/classes over appending to existing files.
- Detailed docs live in `./docs`.
- Make mouse cursor shape responsive to button hovers (`SystemMouseCursors.click`) generally, not case-by-case.


### Resources
- [Best Practices](./docs/best-practices.md)
- [Flutter Docs](https://docs.flutter.dev)
- [Antigravity SDK](https://antigravity.google/docs/sdk/overview)
- [Cursor SDK](https://cursor.com/docs/sdk/python)
- [Claude Code SDK](https://code.claude.com/docs/en/agent-sdk/overview)
- [Codex SDK](https://learn.chatgpt.com/docs/codex-sdk)

### Thanks for reading
