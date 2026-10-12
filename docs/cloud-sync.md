# Cloud sync and notify (stitch-chat)

Stitch Chat keeps a **local SQLite graph** as the UI source of truth. When signed in, selected outbound traffic is replicated to **Stitch cloud** and inbound traffic arrives on **`/ws/v1`**.

## Notify vs sync

| Path | Meaning | Send blocking? |
|------|---------|----------------|
| **Notify** | Cloud recipients must receive a backend notification (HTTP create + fan-out). | **Yes** — failure rolls back the local send. |
| **Sync ledger** | `cloudMessageId` + `syncStatus` on local rows (`none` / `pending` / `synced` / `failed`). | v1: tied to notify success for cloud recipients. |

Future **mirror toggle** (not implemented): any reply in a mirrored subgraph would require a synced parent to sync; sync failure would be non-blocking while notify stays blocking.

## When cloud POST runs (mirror off)

- Message has at least one `RecipientKind.cloudUser` edge with notify intent (v1: all cloud user edges on send).
- User is authenticated (`AuthRepository` + `CloudMessageApi`).

Local-only threads (no cloud recipients) stay `syncStatus: none` with no cloud POST.

## Parent rule (mirror off)

If a send **addresses cloud bots** (`isCloudBot` on a cloud recipient edge), and it is a reply:

- Parent must be **synced** (`cloudMessageId` set, `syncStatus: synced`).
- Otherwise send is blocked with an error (no ancestor backfill).

Starting a new cloud thread (no parent) is allowed.

## Bot context (client-provided)

Cloud bots do **not** receive a bridge-style invoke context array. On `POST /v1/messages`, the desktop attaches the visible-branch **ancestor prefix** (through the reply target, excluding the new trigger) as `context: [...]`.

Backend pass-through (not persisted) puts that list on notification `content.context`; the created message is `content.messages[0]`. Bots use `content.context` as history — same contract as stitch-frontend `sendReply`. Ancestors need not be synced; nodes prefer `cloudMessageId` when present, else the local id.

## Identity and ids

- Backend assigns cloud message ids on create.
- Local sends keep a device uuid; on success we store `cloudMessageId`.
- Inbound WS messages use cloud ids as `Message.id`.
- Graph edges use **local** ids; API `parent_id` uses the parent's `cloudMessageId`.

Dedupe: WS ingest skips ids already present as `id` or `cloudMessageId`.

## Inbound

`StitchBackendWsService` connects with `Authorization: Bearer` when authenticated, parses `type: notification`, and calls `ColumnsViewModel.handleCloudWireMessage` → shared `ingestIncomingMessage` (off-path toast unchanged).

## Refresh reconcile (visible branch)

Toolbar **Refresh** and post-auth `reloadAll` stay local-first, then — when signed in — pull adjacency for every **already-synced** message on each column's **visible branch**:

1. `GET /v1/messages/{cloudMessageId}` for each synced row (`child_ids`, `stitch_parent_ids`, `stitch_child_ids`).
2. Diff against local reply/stitch edges; fetch + persist any missing neighbors.
3. Re-derive the column (`_refresh`). Unset forks still default to the most recent non-hidden reply child, so a new tip reply appears on the branch after refresh.

While that pull runs, the column's bottom thread marker shows **loading**. Failures toast via `NotificationService` (non-blocking); local rows stay usable.

This is catch-up for missed WS / offline arrivals — not login backfill of arbitrary history, and not a full tree walk beyond the visible branch.

## Auth gate

Without sign-in: no cloud user search, no `@`/`#` highlighting, no backend WS, no cloud POST, no refresh reconcile.

## UI

- Per-message: sync status in the message contextual (`...`) menu (`none` omitted).
- Column: aggregate over reply-connected tree from anchor (`pending` spinner / `failed` cloud-off).
- Badges: ☁️ cloud Stitch user; 💻 local bridge bot or cloud `is_bot`.

## Related code

- `lib/data/services/cloud_message_api.dart` — POST `/v1/messages` (optional `context`), GET `/v1/messages/{id}`
- `lib/domain/context_chain.dart` — visible-branch prefix + `messagesToCloudContext`
- `lib/data/services/stitch_backend_ws_service.dart` — inbound WS
- `lib/domain/cloud_send_guard.dart` — parent / cloud-bot rules
- `lib/domain/cloud_edge_reconciler.dart` — visible-branch edge catch-up
- `lib/ui/columns/columns_viewmodel.dart` — send + ingest + reload orchestration
