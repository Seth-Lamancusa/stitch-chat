## Stitch Chat

> Status note: much of the functionality described below remains unimplemented.

Stitch Chat is a desktop app for interacting with coding agents, chatbots, and human users alike. Integrations include OpenAI-compatible model response servers (OpenAI, Anthropic, OpenRouter, etc) local model servers (Ollama, LM Studio, etc), and coding agent runtimes that include built-in prompting and orchestration (Cursor, Claude Code, Codex, Antigravity, DS Harness, OpenCode, AIder, Meta Muse). We interface with these servers and runtimes alike via a local proxy that normalizes their various formats and response mechanisms to a universal interface. Our Cloud backend facilitates human participation in the same spaces. Stitch aims to bring together local model or agent runtimes, cloud-based providers, and collaboration with human beings.

You can talk to local models, coding agents, or cloud model response providers (via the local proxy) without authenticating with your Stitch account, but authenticating buys you human messaging, cloud Stitch bot messaging, and sync with the web app.

Run with `flutter run` to develop.

See the `Adapter Contract` section to develop or integrate your own bot runtime.


### Architecture

Cursor, Antigravity, Codex, and Claude Code expose Python SDKs. OpenAI, Anthropic, Google, and OpenRouter expose remote REST APIs, and local harnesses like Ollama and OpenCode host them on your machine. DS Harness runs one-shot headless with `dsh`. We use an IPC pattern to comminicate between our Flutter application and a lightweight Python server. The Python server handles API calls, local server lifecycle, subprocess invocation, and SDK interaction and normalizes responses from diverse model providers or runtimes.

flutter-project-root/
├── python-server/          # Your Python project
│   ├── main.py             # Entry point
│   ├── requirements.txt    # Dependencies (e.g., flask, pandas)
│   ├── venv/               # Local virtual environment (ignored in git)
│   └── build_dist.sh       # A script to run PyInstaller
├── assets/                 # Where the built binary lives
│   └── bin/
│       └── server_linux    # The output from PyInstaller
├── lib/                    # Flutter source
└── pubspec.yaml            # Add assets/bin/ to assets:


#### Data Model

Stitch utilizes a generic data model for tracking conversations, messages, and function invocations. Instead of centering the data model on the thread (a linear string of messages), we center the message object itself and support connections between them. The fundamental data model is that of the message. Abstractly:

```
class Message:
    content: str
    author: str FK                 # author ID or tag
    type: str                    # text, image, function call, function result, system prompt
    parent-message-id: str       # connects replies to parent
    git-commit: opt str
    etc
```

This enables A/B iteration on prompts, models and context windows (via thread branching or forking - replying multiple times to the same message in the same or different contexts, or invoking several models), automation thereof, as well as built-in version control for comparing results between coding runtimes. Each set of messages simply connected by reply ancestry / descendence is a conversation tree with a single root message, and a linear subset of a conversation tree acts as the rendered thread and context object.

#### Python Runtime Registry

Bot requests are dispatched by runtime, not hardcoded per bot. Each bot is a `BotConfig {bot_id, runtime, params}` — `runtime` selects a handler class, `params` differentiate individual bots that share the same handler (e.g. base_url, model name, api_key). There are three runtime regimes:

* **SDK regime** — one handler per SDK, since each has its own session/invocation model: `ClaudeCodeHandler`, `CursorHandler`, `AntigravityHandler`. No sharing across these beyond the common `handle(message) -> response` interface.
* **API regime** — fewer handlers than bots, shared by contract shape rather than by provider:
  e.g. `OpenAICompatibleHandler(base_url, model)` — covers OpenRouter (cloud) and Ollama (local), and any future provider speaking OpenAI's chat/completions schema. One class, many bots via different `params`.
* **Subprocess invocation** - direct subprocess invocation for any tool that natively prefers headless invocation or doesn't expose an API or SDK.

We dispatch runtime requests asychronously, in paralell, and receive responses via adapter SDKs (WS terminates on bridge, it doesnt touch runtimes). In essence, we tell the bridge server when a message addressing a registered bots was posted, forward it to an adapter SDK, and allow the adapter implementation and runtime together to decide how to respond, including to multiple messages coming in quick succession, optionally enabling parallel responses to the same message (e.g. respond to / comment on each, chain to latest, reply to same). The websocket server simply receives asynchronous stitch messages at the SDK interface. 

Note: the difference between an arbitrary runtime SDK (e.g. Claude Code SDK) and its adapter SDK (which plugs it into the runtime handler). These are generally only the same when the runtime SDK was developed for Stitch. 

In API regime the distinction collapses — `OpenAICompatibleHandler` is the adapter and there's no separate runtime SDK, just a REST contract. 

There is a shared subprocess base handling spawn/capture/timeout/kill/etc supplying only the output-parsing and command-construction logic.

Separation: A `RuntimeRegistry` maps `bot_id -> (handler class, params)`. Handlers assume their `base_url` is already live and only do request/response — they don't manage process lifecycle. Local API runtimes (OpenCode, Ollama) need a local server process running before a handler can talk to them. A `LocalServerManager` checks whether a runtime depends to a local server and whether it's already up, spawns it if not, health-checks it, and tears it down on app exit. Handlers for local runtimes depend on this but don't own it, and return regular HTTP status codes.


### Interface

We use a WebSocket connection between the Dart client and the Python server to exchange information. This enables "typing" indicators, response part streaming, and asynchronous invocation of different models. Dart doesn't know how to talk to any runtime, it only knows *which bot* a message is for. It looks up the bot locally and forwards the message to the Python server over the WS. All the runtime-specific work happens on the far side of that hop.

* Flutter launches the bundled Python server as a local subprocess on app start (see `build_dist.sh`/PyInstaller layout above) and opens one persistent WS connection to it.
* One connection multiplexes every bot and every open conversation — there's no per-bot or per-conversation socket. Every payload carries enough addressing (`bot_id`, `parent_message_id`) for either side to route it.

Each response runtime (any regime) is expected to provide the following input options:
* A way to specify what model and version to use (Dart sends bot ID and canonical version, bridge maps to runtime and bespoke model / version combination), e.g.
   - "@claude-code:sonnet-5.6 ..." --> claude code runtime + model
   - "@cursor:gpt-sol-5.6" --> cursor runtime + model
   - "@chatgpt:gpt-sol-5.6" --> OpenAI runtime, OpenAI endpoint + model^
* A way to specify the cwd

And output fields:
* One or more responses (optionally over time) - rendered and ingested on Dart side as list of consecutive messages by the same author with previous (chained) parent IDs
* Token usage by in / out and pricing (for cost calculation)

**What about MCP capabilities and function calling?** - OPEN

^ ChatGPT could be invoked via OpenAI, OpenRouter, or coding orchestration harnesses. Typically, one popular model will have a canonical user ID that maps to a simple response endpoint (be it OpenRouter or provider-hosted), and agentic coding harnesses are invoked as their own bot users (with version deciding the model). Note that the model / version paradigm is flexible, and it's also possible to configure multiple versions of chatgpt for each endpoint: e.g. "@chatgpt:openrouter" vs "@chatgpt:openai". Thinking effort can also be folded into model verisons as e.g. "@claude-code:sonnet-5.6-high" for high effort. This generally goes for any SDK options. Stitch has canonical users with IDs and possibly mutliple versions, the backend registers these as cloud users, and the Flutter app in this repo registers them locally and associates them with a runtime and parameterization.


### Cloud-based Interaction

The proxy server handles responses instantaneously (arbitrarily finite response time, returned in-process). Human user responses are not necessarily instantaneous, and of course are not generated by a local runtime (conceptually this may be true for model responses too). Bots registered with our local runtime are tagged in the UI as "local users". A user may authenticate with the Stitch cloud for message sync, private message access, and posting messages to other users.

**Before authenticating** - Before authenticating with the Stitch cloud, a user can interact with local models configured as runtimes, and also access public cloud messages by cloud users.

**After authenticating** - After authenticating, a user can access their private messages via the Stitch Chat app, post messages to other cloud users, and sync their messages (including interactions with local bots) with the Stitch cloud backend.

A small laptop emoji chip beside user tags in message tags or author labels distinguish cloud from local users.


### Notes

Use a Process Manager pattern (e.g., Python's psutil). When the LocalServerManager stops a bot, it should traverse the process tree (SIGTERM) of the specific child PID to ensure the environment is fully wiped. Don't bundle one large environment. Use venv per SDK. Give each SDK handler its own directory. This avoids dependency hell between, say, an old version of anthropic's SDK and a newer Cursor SDK. Rather than hardcoding the `RuntimeRegistry`, let the Python server provide a manifest upon connection with available runtimes for dynamic bot availability UI.

We do not stream individual tokens, but content parts like response text blocks, function invocations, and responses. We do not collect or persist "thinking" or "reasoning" blocks.


### Error Handling

All user-facing errors route through a single `NotificationService` (`lib/core/notifications/`) rather than living as ad-hoc state on individual ViewModels. A ViewModel or repository that hits an error calls `notificationService.showError(...)` instead of holding its own `errorMessage` field — this is what "centralize error handling" (see `docs/flutter-best-practices.md`) means concretely in this codebase.

* **Toast (non-blocking, default)** — for errors scoped to a single operation, e.g. one message failing to send. The rest of the app stays usable. Auto-dismisses after its `duration`, or on manual close; both dismissal paths animate the same way.
* **Blocking banner** (`blocking: true`) — reserved for errors that make the whole app unusable in its current state (e.g. the Python server connection is down). Persists until the user dismisses it. Use sparingly — defaulting to blocking trains users to reflexively dismiss without reading.
* Every notification (toast or banner) gets a copy button for free, so users can paste error text into a bug report without transcribing it.
* `NotificationOverlay` renders whatever `NotificationService` currently holds and wraps the app root — new screens/ViewModels don't need to render their own error UI, just inject `NotificationService` and call it.


## Tips

* Prefer creating new files for new logic, classes, and so on over appending to existing files.
* For detailed documentation, see the `./docs` directory.
* Make the mouse cursor shape responsive to button hovers (e.g. `SystemMouseCursors.click`) in general, not just on a case-by-case basis.



## Resources

- [Flutter Docs](https://docs.flutter.dev)
- [Antigravity SDK](https://antigravity.google/docs/sdk/overview)
- [Cursor SDK](https://cursor.com/docs/sdk/python)
- [Claude Code SDK](https://code.claude.com/docs/en/agent-sdk/overview)
- [Codex SDK](https://learn.chatgpt.com/docs/codex-sdk)
