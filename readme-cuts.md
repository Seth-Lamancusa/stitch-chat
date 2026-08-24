# README content cut between 78d7b5f and 2eb39b6

Not a full diff — just substance that was dropped rather than reworded/simplified. For your review; fold back in wherever it still applies.

## Entirely deleted sections

**Notes**
- Use a Process Manager pattern (`psutil`). `LocalServerManager` should SIGTERM the whole process tree of the child PID on stop, not just the PID, so the environment is fully wiped.
- Don't bundle one large environment — use a venv per SDK, own directory per SDK adapter, to avoid dependency hell (e.g. old Anthropic SDK vs newer Cursor SDK). Ties to the launch-declaration open question: an adapter running as its own supervised process solves isolation and would enable confinement later via the same mechanism.
- Don't hardcode `RuntimeRegistry` — let the bridge provide a manifest on connection with available runtimes, for dynamic bot-availability UI.
- We stream content parts (text blocks, function invocations/results), not individual tokens. We do not collect or persist thinking/reasoning blocks.

**Error Handling**
- All user-facing errors route through a single `NotificationService` (`lib/core/notifications/`) rather than ad-hoc `errorMessage` state on ViewModels.
- Toast (non-blocking, default) — scoped to one failed operation, rest of app stays usable, auto-dismisses.
- Blocking banner (`blocking: true`) — reserved for app-unusable errors (e.g. bridge connection down), persists until dismissed. Use sparingly — default-blocking trains users to reflexively dismiss.
- Every notification gets a copy button for free (paste error text into a bug report without transcribing).
- `NotificationOverlay` renders whatever `NotificationService` holds, wraps app root — new screens/ViewModels just inject the service, no bespoke error UI.

**Tips**
- Prefer new files for new logic/classes over appending to existing files.
- Detailed docs live in `./docs`.
- Make mouse cursor shape responsive to button hovers (`SystemMouseCursors.click`) generally, not case-by-case.

**Resources**
- [Flutter Docs](https://docs.flutter.dev)
- [Antigravity SDK](https://antigravity.google/docs/sdk/overview)
- [Cursor SDK](https://cursor.com/docs/sdk/python)
- [Claude Code SDK](https://code.claude.com/docs/en/agent-sdk/overview)
- [Codex SDK](https://learn.chatgpt.com/docs/codex-sdk)

**Cloud-based Interaction**
- Bridge handles responses in-process with arbitrarily finite response time; human responses aren't instantaneous, and conceptually neither are model responses.
- Bots on the local runtime are tagged "local users" in the UI.
- Before authenticating: interact with local models, access public cloud messages from cloud users.
- After authenticating: access private messages, post to other cloud users, sync local-bot interactions with cloud backend.
- Small laptop-emoji chip beside user tags distinguishes cloud vs. local users. Local users can proxy to a cloud provider — likely confusion source; may eventually need to distinguish truly-local runtimes from local cloud-proxies at the Dart/Python contract.

**Repo and Build Layout**
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
Flutter launches the bundled Python bridge as a local subprocess on app start and opens one persistent WS connection to it.

**Edge cases and follow-up risk** (under Environments/Snapshots)
- Disk consumption is the main practical risk given untracked files are included. Mitigation: exclusion defaults for pathological cases (`node_modules`, `target`, `.venv`) as a space policy, not a correctness one. Measure early against real project directories.
- Snapshot atomicity — a snapshot mid-write can capture an incoherent tree (file written but not the file that imports it). Self-healing (next snapshot catches up); a truthfulness caveat, not data loss.
- Out-of-environment reads/writes — shell access lets a bot reach outside its directory (remembered absolute path, external tool, shared cache); those writes escape tracking. **Accepted for v1.** Interactive case: diff missing a file, shrug. Real exposure: unattended concurrent comparison, where cross-contamination produces clean-looking but wrong results — hitting exactly the audience most likely to trust the numbers.
- Monitoring, deferred — syscall-level detection possible but not shippable (fanotify/eBPF need root, macOS Endpoint Security needs an Apple entitlement, Windows needs ETW/minifilter; Landlock audit logging is the right fit but needs 6.17+). Cheap interim moves: pre/post snapshot divergence (free, already snapshotting both sides) and mtime scanning of a small allowlist of suspect paths. Instrumented Linux dev builds could answer "how often does this happen" with much smaller n than field monitoring.
- git object model limits — no ownership, no xattrs, symlinks stored as blobs. Fine for source trees; worth knowing before pointing Stitch at something exotic.

## Substantive reasoning/decisions dropped from sections that otherwise survived

- **"Why not sandboxing"** — explicit argument against OS-level confinement (Landlock/Seatbelt/AppContainer): three implementations, one bad on Windows; guarantee only holds for processes Stitch itself spawns, constraining the adapter contract; runtimes already ship their own permission models and compete on them; "a partial confinement guarantee is worse than none — it converts a vendor's problem into ours and teaches users to relax."
- **Bot's own git operations** — record `(HEAD, dirty?)` before invocation; at each snapshot point, if HEAD moved attribute that commit range to the message, if worktree also dirty add a Stitch snapshot on top. One reconciliation rule covers "committed," "didn't commit," "committed then kept working." Bot's commits stay the bot's; attribution is a mapping, not a rewrite.
- **Real repos as overlay, not the mechanism** — when writing into a real repo, use plumbing with `GIT_INDEX_FILE` pointed at a scratch index, write to `refs/stitch/<message-id>` rather than moving any branch — never touch the user's staging area or branch history.
- **Snapshot mechanism specifics** — walk the directory ourselves: `hash-object -w` each file, `update-index --cacheinfo`, `write-tree`, `commit-tree`. Because we do the walk: no ignore rules (a shadow worktree would read `.gitignore`, silently making an incomplete snapshot); no gitlinks (`git add` over a nested `.git` records a bare commit pointer and snapshots none of the contents — broken for the main use case of environments containing real, possibly several, repos); above the OS (one implementation, no per-platform branching, no elevated privileges).
- **Environment-per-node materialization details** — materialization is `cp --reflink=auto`/`clonefile` where supported (APFS, btrfs/XFS, Dev Drive), plain copy otherwise — a flag, not a subsystem. Cleanup keys off retention policy rather than lifecycle bookkeeping: materializations are derivable from snapshots, so garbage-collect aggressively and rematerialize on demand.
- **Timing** — snapshot resolves before the node is handed to Dart; on a multi-minute task the user just sees "typing" for a few extra seconds, even 10+s of snapshot latency goes mostly unnoticed. Cost is per-ack, so a long chained emission pays it several times in one invocation. Escape hatch if that bites: snapshot on invocation boundaries by default, per-node only when the adapter declares it emits filesystem-relevant work between nodes.
- **Two explicitly open questions**, stubbed deliberately, now gone without a trace:
  1. A *launch declaration* (argv, env, cwd requirement) letting the bridge spawn adapter processes rather than adapters spawning their own — not needed yet, but the shape that enables per-invocation confinement later, dovetailing with venv-per-SDK isolation.
  2. MCP capabilities and function calling.
- **`reply_to` validation mechanism** — bare message ID at the adapter interface (real IDs, scoped by who's allowed to cite which one); bridge validates against a per-invocation allow-set before persisting (WS to Dart); violation surfaces as a bot error.
- **`LocalServerManager`** — checks whether a runtime needs a local server and whether it's already up, spawns it if not, health-checks it, tears it down on app exit. Adapters for local runtimes depend on this but don't own it, return regular HTTP status codes. (Local API runtimes like OpenCode/Ollama need this; SDK/subprocess-regime adapters don't.)
- **Cue channel as a distinct envelope kind** on the multiplexed WS — non-persisted, no ID, keyed by `(author, opt target_node)`, latest-supersedes-previous. Typing indicators are just one `cue.kind` among others (thinking, tool-running, awaiting-approval), not a special case.
- **Terminology callout** — explicit distinction between "adapter" (what a runtime developer implements) and "runtime SDK" (vendor-provided library an adapter may call, e.g. Claude Code SDK); the two coincide only when a runtime SDK was built Stitch-native.
- **Ownership table's negative-space rule** — "Adapter explicitly does not own — storage, git or snapshotting, environment lifecycle, local server lifecycle, or `reply_to` validation," with the load-bearing reasoning: "Third-party adapters are code we didn't write; anything a guarantee depends on has to sit outside them."
