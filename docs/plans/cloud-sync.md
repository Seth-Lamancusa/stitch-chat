# Cloud sync — architecture blueprint

## Premise

Two independent axes, neither of which is "what kind of user":
- **Session axis**: is *this app instance* currently authenticated to the Stitch backend — binary, no network calls attempted at all when not. This is what `CloudSessionState` (§1) models.
- **Message axis**: each message is synced or not, independent of the session's current state (a message can be `synced` while the session is momentarily offline).

Local usage must be a structural guarantee — sync code paths never fire without a cloud session, not a flag that happens to be off.

Not to be conflated with the session axis: who a message is *from* or *to* (`authorId`, `RecipientEdge` — `message-tree-data-model.md` §2) can independently be local or cloud, regardless of the current session's state. A cloud-authenticated session still sends to plenty of local-only bot recipients, and vice versa. §9 covers the one place this plan actually touches recipients: delivery status per cloud recipient, kept distinct from message sync status.

## Components

### 1. `CloudSessionService`

```dart
enum CloudSessionState {
  unauthenticated,          // default — local user
  authenticatedOnline,
  authenticatedError,       // transient: 5xx/timeout/offline — not sticky, clears on next success
  authenticatedAuthExpired, // sticky: 401/403 — blocks all sync until re-auth succeeds
}
```

Every sync-related repository method checks this state first; anything but `authenticatedOnline` short-circuits to a no-op / `NotAuthenticated` result.

### 2. `SyncScopeResolver`

```dart
enum SyncScopeKind {
  visibleColumn,               // ancestors-to-root ∪ column's visible path
  replyComponent,               // ancestors-to-root ∪ full ReplyEdge subtree (SQLite query)
  loadedComponentWithStitches,  // + StitchEdge neighbors, bounded to in-memory loaded set
}
```

`resolve(SyncScopeKind, {required String fromMessageId}) -> Set<String>`. Ancestors-to-root are always included (referential integrity: a message can't push before its parent exists remotely). `SyncEngine` stays scope-agnostic — it takes an id set and enforces ordering within it.

Column rollup indicator always reduces over `visibleColumn`. Wider scopes are opt-in, one-shot, chosen via the column sync modal (§6).

**Cascading ancestor failure**: `SyncEngine` never pushes a message whose parent's `syncStatus` isn't `synced`. Blocked descendants stay at their current status untouched and pick up automatically once the parent clears. Rollup display walks up to the root-most failing ancestor and surfaces that as the blocker, rather than N per-message errors.

### 3. `SyncEngine` (push)

- `SyncOutboxEntry { messageId, createdAt, attempts, lastError }` — drift table, one row per locally-created/edited message pending push. Populated at write time by the message repository.
- `SyncEngine.syncNow({Set<String>? messageIds})` — drains outbox in topological order, enforcing §2a's blocking rule.
  - No `messageIds` → full drain, triggered by debounce timer under the `autoSyncToCloud` setting.
  - `messageIds` given → scope from `SyncScopeResolver`, via the column sync modal.
- Gated by `CloudSessionState`: anything but `authenticatedOnline` → no-op.

### 4. `ReconciliationService` (pull / deletion detection)

- `checkStillExists(Set<String> messageIds)` — batch-checks messages flagged `synced` against the API. Triggered on column-becomes-visible and manual refresh only — never on individual message load (would block rendering on a round trip).
- A message reported gone → `MessageSyncStatus.deletedRemotely`, feeding the same rollup.
- Same `authenticatedOnline` gate as push.

### 5. `Message.syncStatus`

```dart
enum MessageSyncStatus { notSynced, pending, synced, deletedRemotely, error }
```

Single source of truth per message — no separate boolean flags. Column rollup is computed (not stored): a pure reduction over the current scope's `syncStatus` values, recomputed reactively.

### 6. User-facing controls

- **Global setting** `autoSyncToCloud` (bool, persisted) — gates the full-drain debounce timer. Off by default.
- **Per-column rollup badge** → click opens **column sync modal**: pick a `SyncScopeKind`, preview count, confirm. Always available regardless of the global setting.
- Every route (auto-sync, every modal scope kind) goes through the same `SyncEngine.syncNow` with different id sets — no per-scope code path.

### 7. Error routing

Via existing `NotificationService` (README §Error Handling):
- `authenticatedAuthExpired` → toast: "Cloud sign-in expired — reconnect to resume sync." Never blocking.
- Per-message/per-column sync errors → **not** routed through `NotificationService` at all; surfaced only via the column rollup badge.

### 8. Import (cloud → local)

- `CloudImportRepository { searchRemoteChats(query), importChat(remoteId) }`
- `importChat` writes new `Message`/`ReplyEdge` rows directly, `syncStatus = synced`, remote id attached, no outbox entry.
- Own modal + ViewModel. Shares only the `CloudSessionService` gate — no coupling to `SyncEngine`/`SyncOutbox`.

### 9. Recipient delivery ≠ message sync

A message can address multiple recipients (`RecipientEdge`,
`message-tree-data-model.md` §2). Sending is local persistence — it always
succeeds if the SQLite write succeeds, never blocked on any recipient's
cloud reachability. Mirrors stitch-backend's own split: persistence is what
gates the API response, delivery to each recipient happens after and can't
fail the send (`app/db/messages.py:528`, `app/util/notifications.py:119-156`
— delivery failures are logged, never returned to the caller).

- **Local-bot recipients** dispatch through the existing runtime registry
  (README §Python Runtime Registry); failures there are the existing
  per-operation toast path, unrelated to this plan.
- **Cloud-recipient delivery** — did the Stitch backend deliver this
  message to that specific cloud user — is a new per-`RecipientEdge`
  status, gated on `CloudSessionState == authenticatedOnline` like push/
  reconciliation, but distinct from `Message.syncStatus` (§5): a message
  can be `synced` while a given recipient hasn't received it, but not the
  reverse (delivery implies the backend already has the message, i.e.
  synced) — so delivery status is downstream of sync status, not a
  parallel axis.
- Addressing a cloud recipient requires an authenticated session at
  compose time (recipient picker), not a check raced at send time. A
  session lapsing between compose and delivery is just an ordinary
  delivery failure, handled per the bullet above — never a blocking send
  error.
- Delivery status surfaces the same way sync errors do (§7): per-recipient
  rollup, never through global `NotificationService`.

## Build order

1. `CloudSessionService` + auth flow (login modal, token storage, refresh, state machine) — foundation everything else gates on.
2. Schema: `sync_outbox` table, `sync_status` on messages (or side table, TBD).
3. `SyncEngine` + `SyncScopeResolver` (parallel with 4, both only need schema from 2).
4. `ReconciliationService`.
5. Column sync UI: rollup badge, sync modal, `autoSyncToCloud` settings screen (depends on 3 + 4).
6. Cloud import flow (depends only on 1, can proceed independently).

## Next step

Write the focused implementation plan for `CloudSessionService` + auth flow — 2-4 assume its state machine and gating behavior are settled.
