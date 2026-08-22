## Stitch Chat

> Status note: normative, unimplemented

Stitch Chat is a desktop app for interacting with coding agents, chatbots, and human users alike. Integrations include OpenAI-compatible model response servers (OpenAI, Anthropic, OpenRouter, etc), local model servers (Ollama, LM Studio, etc), and coding agent runtimes that include built-in prompting and orchestration (Cursor, Claude Code, Codex, Antigravity, DS Harness, OpenCode, Aider, Meta Muse). We interface with these servers and runtimes alike via a local bridge that normalizes their various formats and response mechanisms to a universal interface. Our cloud backend facilitates human participation in the same spaces. Stitch aims to bring together local model or agent runtimes, cloud-based providers, and collaboration with human beings.

You can talk to local models, coding agents, or cloud model response providers (via the local bridge) without authenticating with your Stitch account, but authenticating buys you human messaging, cloud Stitch bot messaging, and sync with the web app.

Run with `flutter run` to develop.

See [Adapter Contract](#adapter-contract) to develop or integrate your own bot runtime.

**Terminology.** The thing a runtime developer implements is an **adapter**. One adapter plugs one runtime into Stitch. Distinguish it from the **runtime SDK** — the vendor-provided library an adapter may call (e.g. the Claude Code SDK). The two are only the same object when a runtime SDK was built Stitch-native.

---

### Data Model

Stitch utilizes a generic data model for tracking conversations, messages, and function invocations. Instead of centering the data model on the thread (a linear string of messages), we center the message object itself and support connections between them. The fundamental data model is that of the message. Abstractly:

```
class Message:
    content: str
    author: str FK               # author ID or tag
    type: str                    # text, image, function call, function result, system prompt
    parent-message-id: str       # connects replies to parent
    env-snapshot-id: opt str     # content-addressed snapshot of the environment at this node
    repo-refs: opt [ {repo_path, base_oid, head_oid} ]   # derived index over env-snapshot-id, not separately authoritative; may be computed lazily
    etc
```

This enables A/B iteration on prompts, models and context windows (via thread branching or forking — replying multiple times to the same message in the same or different contexts, or invoking several models), automation thereof, as well as built-in version control for comparing results between coding runtimes. Each set of messages simply connected by reply ancestry/descendence is a conversation tree with a single root message, and a linear subset of a conversation tree acts as the rendered thread and context object.

---

### Architecture

Cursor, Antigravity, Codex, and Claude Code expose Python SDKs. OpenAI, Anthropic, Google, and OpenRouter expose remote REST APIs, and local harnesses like Ollama and OpenCode host them on your machine. DS Harness runs one-shot headless with `dsh`. We use an IPC pattern to communicate between our Flutter application and a lightweight Python bridge server. The bridge handles API calls, local server lifecycle, subprocess invocation, and SDK interaction, and normalizes responses from diverse model providers or runtimes.

#### Repo and Build Layout

```
flutter-project-root/
├── python-server/          # Bridge server project
│   ├── main.py             # Entry point
│   ├── requirements.txt    # Dependencies (e.g., flask, pandas)
│   ├── venv/               # Local virtual environment (ignored in git)
│   └── build_dist.sh       # A script to run PyInstaller
├── assets/                 # Where the built binary lives
│   └── bin/
│       └── server_linux    # The output from PyInstaller
├── lib/                    # Flutter source
└── pubspec.yaml            # Add assets/bin/ to assets:
```

#### Ownership

Fixing this table first is what keeps the rest of the contract from drifting. The wire schema falls out of it.

* **Dart owns** — persistence (local and cloud), environment lifecycle (materialization and teardown), snapshot creation, message identity, and the mapping from message node to environment state.
* **Python bridge owns** — runtime invocation, response normalization, process supervision, and `reply_to` validation.
* **Adapter owns** — Stitch message → runtime call, and runtime output → Stitch nodes. That is the whole job.
* **Adapter explicitly does not own** — storage, git or snapshotting, environment lifecycle, local server lifecycle, or `reply_to` validation.

The last line is the load-bearing one. Third-party adapters are code we didn't write; anything a guarantee depends on has to sit outside them.

All conversation and state persistence (local or cloud) is owned by the Dart application. There are two data repository implementations that share a common shape, one for the Stitch cloud and one for the local drift-backed sqlite DB.

#### Adapter Contract

One thin interface across all three regimes. An adapter receives an invocation and emits nodes:

```
class Adapter:
    def handle(self, invocation) -> None:   # emits nodes via the bridge as it goes
```

The invocation carries the trigger message, the bot's `params`, and the environment `cwd` (where applicable — no cwd for plain response providers). Emission is asynchronous and multi-node.

Shared primitives live on the bridge, not on regime base classes, so an invariant is enforced once rather than three ways: `reply_to` allow-set validation, `BotConfig`/`params` schema checks, timeout and cancellation, and error surfacing. Regime base classes exist only where a regime genuinely implies shared mechanics — which is really just subprocess.

**Open:** a *launch declaration* (argv, env, cwd requirement) that lets the bridge spawn adapter processes rather than adapters spawning their own. Not needed for anything we've committed to, but it's the shape that would enable per-invocation confinement later, and it dovetails with venv-per-SDK isolation (see [Notes](#notes)). Stubbed deliberately.

**Open:** MCP capabilities and function calling.

#### The Three Regimes

Each bot is a `BotConfig {bot_id, runtime, params}` — `runtime` selects an adapter class, `params` differentiate individual bots sharing that adapter (e.g. `base_url`, model name, api_key). Bot requests are dispatched by runtime, not hardcoded per bot. The regimes differ in *how much they share and at what layer*, which is what a runtime developer needs to know to size the job:

* **SDK regime** — one adapter per SDK, since each has its own session/invocation model: `ClaudeCodeAdapter`, `CursorAdapter`, `AntigravityAdapter`. Nothing is shared across these beyond the interface itself; three unrelated SDKs don't have common behavior worth extracting, and forcing some would fight the grain. Responses come in through the runtime SDK, which the adapter wraps.
* **API regime** — already maximally shared, and by a structural route rather than inheritance: `OpenAICompatibleAdapter(base_url, model)` is *one concrete class* covering OpenRouter (cloud), Ollama (local), and any future provider speaking OpenAI's chat/completions schema. One class, many bots via different `params`. There is no separate runtime SDK here, just a REST contract.
* **Subprocess regime** — direct invocation for any tool that natively prefers headless invocation or doesn't expose an API or SDK (DS Harness via `dsh`). This is the one regime with a real base class carrying behavior: **the shared base owns process lifecycle** — spawn, capture, timeout, kill, process-tree teardown. **Command construction and output parsing are per-tool**, supplied by the subclass, since no two headless tools agree on argv shape or output format. This mirrors the API regime's split between shared contract and per-bot params.

#### Dispatch

We dispatch runtime requests asynchronously and in parallel, and receive responses via adapters. The WebSocket terminates on the bridge; it doesn't touch runtimes. In essence: we tell the bridge when a message addressing a registered bot was posted, it forwards to the adapter, and the adapter and runtime together decide how to respond — including responding to multiple messages arriving in quick succession, and optionally responding in parallel to the same message (comment on each, chain to latest, reply to same).

**Multiple bots can be tagged on a single message.** Each is dispatched independently and picks up the work at effectively the same moment (fan-out is synchronous, sub-millisecond). This is the feature that makes the tree data model pay off — tag two coding agents on one message and compare what comes back — and it means concurrency is the primary comparison workflow, not an edge case. Everything in [Environments and Snapshots](#environments-and-snapshots) is designed around that assumption.

A `RuntimeRegistry` maps `bot_id -> (adapter class, params)`. Adapters assume their `base_url` is already live and only do request/response — they don't manage process lifecycle. Local API runtimes (OpenCode, Ollama) need a local server process running before an adapter can talk to them. A `LocalServerManager` checks whether a runtime depends on a local server and whether it's already up, spawns it if not, health-checks it, and tears it down on app exit. Adapters for local runtimes depend on this but don't own it, and return regular HTTP status codes.

**`reply_to` is a bare message ID** at the adapter interface, not an opaque token — the ID space is real IDs, just scoped by who's allowed to cite which one. An adapter may cite any node it has *seen* this invocation: the trigger, plus any of its own prior emissions once ack'd. The bridge validates against this per-invocation allow-set before persisting (WS to Dart). Violation surfaces as a bot error.

**Chaining is unrestricted, not single-response.** Adapters can emit arbitrarily many multi-part nodes per invocation, chained however they like — reasoning/work-log off to a side branch to keep it out of context, chained multipart responses as revert/fork points, etc.

#### Transport

We use a WebSocket connection between the Dart client and the Python bridge. This enables typing indicators, response part streaming, and asynchronous invocation of different models. Dart doesn't know how to talk to any runtime; it only knows *which bot* a message is for. It looks up the bot locally and forwards the message to the bridge over the WS. All runtime-specific work happens on the far side of that hop.

* Flutter launches the bundled Python bridge as a local subprocess on app start (see `build_dist.sh`/PyInstaller layout above) and opens one persistent WS connection to it.
* One connection multiplexes every bot and every open conversation — there's no per-bot or per-conversation socket. Every payload carries enough addressing (`bot_id`, `parent_message_id`) for either side to route it.
* **The cue channel is a second, separate envelope kind** on the same multiplexed socket — non-persisted, no ID, keyed by `(author, opt target_node)`, latest-supersedes-previous. Typing indicators are one `cue.kind` among others (thinking, tool-running, awaiting-approval), not a special case.

Each response runtime (any regime) is expected to accept the following inputs:

* Model and version^ — Dart sends bot ID and canonical version, the bridge maps to runtime and bespoke model/version combination:
   - `@claude-code:sonnet-5.6 ...` → Claude Code runtime + model
   - `@cursor:gpt-sol-5.6` → Cursor runtime + model
   - `@chatgpt:gpt-sol-5.6` → OpenAI runtime, OpenAI endpoint + model^
* A cwd (where applicable).

And to emit:

* One or more responses, optionally over time — rendered and ingested on the Dart side as a list of consecutive messages by the same author with previous (chained) parent IDs.
* Token usage by in/out and pricing, for cost calculation.

^ ChatGPT could be invoked via OpenAI, OpenRouter, or coding orchestration harnesses. Typically one popular model will have a canonical user ID mapping to a simple response endpoint (OpenRouter or provider-hosted), and agentic coding harnesses are invoked as their own bot users, with version deciding the model. The model/version paradigm is flexible: multiple versions of chatgpt can be configured per endpoint, e.g. `@chatgpt:openrouter` vs `@chatgpt:openai`. Thinking effort folds into model versions the same way, e.g. `@claude-code:sonnet-5.6-high`. This generally goes for any SDK options. Stitch has canonical users with IDs and possibly multiple versions; the backend registers these as cloud users, and the Flutter app registers them locally and associates them with a runtime and parameterization. That's the obvious level of end-user abstraction.

---

### Environments and Snapshots

> Detail lives in `docs/environments.md`; this section is the load-bearing claim only.

**Stitch owns the environment's history. Adapters own execution. Confinement is the runtime's problem.**

An environment is a directory a bot runs in. Stitch snapshots it and maps snapshots to message nodes, so that "what the filesystem looked like at this message" is always answerable — and so that forked branches of a conversation can be compared as diffs rather than vibes. This is the reason to bring multiple runtimes under one roof at all; without it Stitch is a chat UI over model providers.

**Why not sandboxing.** We considered having Stitch enforce "no writes outside the environment" at the OS level (Landlock, Seatbelt, AppContainer). Cut, deliberately: it's three implementations, one of which is genuinely bad on Windows; the guarantee only holds for processes Stitch itself spawns, which would constrain the adapter contract considerably; and the runtimes already ship their own permission models and compete on them. A *partial* confinement guarantee is worse than none — it converts a vendor's problem into ours and teaches users to relax. Confinement is declared per-runtime and surfaced in the UI, not promised by Stitch.

Snapshotting and sandboxing are separable. Snapshotting a directory doesn't require confining anything to it; confinement would only make the snapshot *complete*. Since runtimes point themselves at a cwd, essentially all the work lands inside it anyway.

#### Mechanism

We use git as a **content-addressed object store, not as a working-copy manager.**

* **Snapshot** — walk the directory ourselves, `hash-object -w` each file, build the index with `update-index --cacheinfo`, `write-tree`, `commit-tree`.
* **Materialize** — read the tree object, write the files out.

Because we do the walk, git never inspects the filesystem and never applies its own opinions. This matters more than it sounds:

* **No ignore rules.** A shadow worktree pointed at the environment would read the environment's `.gitignore` — silently making a snapshot that's supposed to be comprehensive not comprehensive.
* **No gitlinks.** `git add` over a directory containing a nested `.git` records a bare commit pointer and snapshots *none of the contents*. Since the normal case is "the environment contains a real repo," and a stated requirement is "possibly several," the shadow-worktree approach was broken for the main use case, not merely leaky. Doing our own walk makes nested repos just directories with files in them, `.git` contents included.
* **Above the OS.** One implementation, no per-platform branching, no elevated privileges.

Objects are deduplicated by content, so most snapshots are cheap regardless of directory size.

**Untracked files are included, and bots may modify files no repo tracks.** That was a deliberate call for practical reasons, and it's costless here precisely because tracking no longer depends on the user having a repo.

**Real repos are an overlay, not the mechanism.** When the environment contains actual repos, we additionally record `(repo_path, base_oid, head_oid)` per repo. When writing into a real repo, use plumbing with `GIT_INDEX_FILE` pointed at a scratch index and write to `refs/stitch/<message-id>` rather than moving any branch — never touch the user's staging area or branch history.

**When a bot does its own git operations** (Claude Code commits unprompted; this is common), don't fight it and don't special-case it. Record `(HEAD, dirty?)` before invocation. At each snapshot point, if HEAD moved, attribute that commit range to the message; if the worktree is also dirty, add a Stitch snapshot on top. One reconciliation rule covers "bot committed," "bot didn't commit," and "bot committed then kept working." The bot's commits stay the bot's; our attribution is a mapping, not a rewrite.

#### Environment per node

Every message node has an environment **identity** — a stable ID, the snapshot it derives from, and the path it would live at. Materialization is **lazy**: it happens on first invocation that needs it. Nodes with no filesystem work cost nothing; chained nodes within one invocation share the live directory rather than each spawning one. So the model stays uniform per node while the actual directory count tracks invocations.

Materialization is `cp` with `--reflink=auto` / `clonefile` where the filesystem supports it (APFS, btrfs/XFS, Dev Drive) and a plain copy where it doesn't. That's a flag, not a subsystem — no OS-specific code we own.

Cleanup keys off retention policy rather than lifecycle bookkeeping: materializations are derivable from snapshots, so garbage-collect aggressively and rematerialize on demand.

Concurrent invocations require real separate directories — there's no diffing-in-place shortcut when N processes write simultaneously, and multi-agent tagging makes that the common case.

#### Timing

Snapshot resolves before the node is handed to Dart. On a task measured in minutes, the user sees the bot "typing" for a few extra seconds; even 10+ seconds of raw snapshot latency goes mostly unnoticed. Note the cost is per-ack, so a long chained emission pays it several times in one invocation.

**Escape hatch if that bites:** snapshot on invocation boundaries by default, per-node only when the adapter declares it emits filesystem-relevant work between nodes.

#### Edge cases and follow-up risk

* **Disk consumption** is the main practical risk, given untracked files are included. Mitigation is an exclusion default for the pathological cases (`node_modules`, `target`, `.venv`) as a space policy rather than a correctness one. Measure early against real project directories.
* **Snapshot atomicity** — a snapshot taken while an agent is mid-write can capture a tree that never coherently existed (e.g. a file written but not the file that imports it). Self-healing, since the next snapshot catches up, and only reachable at write intervals comparable to disk operations. It's a truthfulness caveat on the mapping, not a data-loss risk: "mapped to this message, best-effort."
* **Out-of-environment reads and writes** — a bot with shell access can reach outside its directory: a remembered absolute path, an external tool, a shared cache. Those writes escape tracking. **Accepted for v1.** For interactive use the result is a diff missing a file and a shrug. The real exposure is unattended concurrent comparison, where cross-contamination produces clean-looking results that are *wrong* — and the audience most likely to hit it is the one most likely to trust the numbers.
* **Monitoring, deferred.** Syscall-level detection is possible but not shippable: fanotify/eBPF need root, macOS Endpoint Security needs an Apple-granted entitlement, Windows needs ETW or a minifilter. Landlock audit logging is the conceptually right fit but 6.17+. If this surfaces, the cheap moves are pre/post snapshot divergence (free — we already snapshot both sides) and mtime scanning of a small allowlist of known-suspect paths. Instrumented Linux dev builds can answer "how often does this actually happen" with a much smaller n than field monitoring would.
* **git object model limits** — no ownership, no xattrs, symlinks stored as blobs. Fine for source trees; worth knowing before someone points Stitch at something exotic.

---

### Cloud-based Interaction

The bridge handles responses in-process with arbitrarily finite response time. Human user responses are not necessarily instantaneous, and conceptually this may be true for model responses too. Bots registered with our local runtime are tagged in the UI as "local users." A user may authenticate with the Stitch cloud for message sync, private message access, and posting messages to other users.

**Before authenticating** — a user can interact with local models configured as runtimes, and access public cloud messages by cloud users.

**After authenticating** — a user can access their private messages via the Stitch Chat app, post messages to other cloud users, and sync their messages (including interactions with local bots) with the Stitch cloud backend.

A small laptop emoji chip beside user tags in message tags or author labels distinguishes cloud from local users. Note that local users can proxy to a cloud provider. Someone will get confused by that, and eventually we might distinguish truly local runtimes from local cloud proxies at the Dart/Python contract.

---

### Notes

Use a Process Manager pattern (e.g. Python's `psutil`). When the `LocalServerManager` stops a bot, it should traverse the process tree (SIGTERM) of the specific child PID to ensure the environment is fully wiped.

Don't bundle one large environment. Use a venv per SDK, and give each SDK adapter its own directory. This avoids dependency hell between, say, an old version of Anthropic's SDK and a newer Cursor SDK. (It also points the same direction as the launch-declaration open question above — an adapter running as its own supervised process solves isolation and would later enable confinement with one mechanism.)

Rather than hardcoding the `RuntimeRegistry`, let the bridge provide a manifest upon connection with available runtimes, for dynamic bot availability UI.

We do not stream individual tokens, but content parts: response text blocks, function invocations, and results. We do not collect or persist thinking/reasoning blocks.

---

### Error Handling

All user-facing errors route through a single `NotificationService` (`lib/core/notifications/`) rather than living as ad-hoc state on individual ViewModels. A ViewModel or repository that hits an error calls `notificationService.showError(...)` instead of holding its own `errorMessage` field — this is what "centralize error handling" (see `docs/flutter-best-practices.md`) means concretely in this codebase.

* **Toast (non-blocking, default)** — for errors scoped to a single operation, e.g. one message failing to send. The rest of the app stays usable. Auto-dismisses after its `duration`, or on manual close; both dismissal paths animate the same way.
* **Blocking banner** (`blocking: true`) — reserved for errors that make the whole app unusable in its current state (e.g. the bridge connection is down). Persists until the user dismisses it. Use sparingly — defaulting to blocking trains users to reflexively dismiss without reading.
* Every notification (toast or banner) gets a copy button for free, so users can paste error text into a bug report without transcribing it.
* `NotificationOverlay` renders whatever `NotificationService` currently holds and wraps the app root — new screens/ViewModels don't need to render their own error UI, just inject `NotificationService` and call it.

---

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
