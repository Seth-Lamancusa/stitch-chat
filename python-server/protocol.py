"""Wire protocol constants for the Dart <-> Python WebSocket connection.

Envelopes are flat JSON objects with a "type" field. Every message-bearing
envelope carries message_id/parent_message_id/bot_id so the message tree
can be built without changing this shape later.

`user_message.context` is the column's visible context window for this
invoke: Stitch nodes through the reply target, with the trigger message
as the final node. Not a Completions messages[] — projection happens
inside adapters. `message_id` is the trigger's id (parent of bot replies).

Optional `user_message.cwd` is a column tag (filesystem path or empty),
passed at invoke time — not message state. Bots that advertise
`requires_cwd` must receive it; the bridge responds with
`invoke_skipped` (not `error`) and does not run the adapter.

Multi-part bot turns (Cursor side-channel) may emit several
`message_start`/`message_end` pairs per invoke. Optional fields:
  - `role`: thinking | functionCall | functionResult | localBot
  - `invoke_root_id`: trigger id for correlation when parent_message_id
    chains under a prior part of the same invoke
  - `is_final`: true on the last reply-branch message_end (completes invoke)
  - `tool_name` / `tool_call_id` / `is_error`: tool metadata on function parts
  - `hidden`: true on message_end when the reply edge from
    parent_message_id → this message should be skipped by default path
    walks (first Cursor side-fork hop). Dart persists it on ReplyEdges.
"""

from dataclasses import dataclass

READY = "ready"
USER_MESSAGE = "user_message"
MESSAGE_START = "message_start"
MESSAGE_END = "message_end"
INVOKE_SKIPPED = "invoke_skipped"
ERROR = "error"
CUE = "cue"

DEFAULT_MODEL = "gpt-4o-mini"


def cue_envelope(
    *,
    author_id: str,
    target_message_id: str,
    typing: bool,
) -> dict:
    """Ephemeral typing cue — not a graph node, never persisted.

    Keyed by (author_id, target_message_id). typing=True turns the cue on;
    typing=False clears that key only. The same author may have several active
    targets (parallel invokes).
    """
    return {
        "type": CUE,
        "author_id": author_id,
        "target_message_id": target_message_id,
        "typing": typing,
    }


@dataclass(frozen=True)
class BotSpec:
    """A local bot the bridge can dispatch to, plus every @tag that resolves
    to it. `id` is included in `aliases` so callers can treat both the same.

    `requires_cwd` is enforced on the bridge before adapter dispatch via
    `invoke_skipped` (not `error`). Clients may also read it from `ready`
    to surface composer warnings.
    """

    id: str
    aliases: frozenset[str]
    requires_cwd: bool = False


# Single source of truth for local bots. Add an entry here to register a new
# bot or tag — nothing else in this module (or the Dart client, which mirrors
# this list from the `bots` field on the `ready` envelope) special-cases a
# bot id or alias by name. Adapter implementations live in `adapters.ADAPTERS`.
BOT_REGISTRY: tuple[BotSpec, ...] = (
    BotSpec(id="chatgpt", aliases=frozenset({"chatgpt", "openai"})),
    BotSpec(id="cursor", aliases=frozenset({"cursor"})),
)

DEFAULT_BOT_ID = BOT_REGISTRY[0].id

# Local bot ids the bridge currently knows how to dispatch.
KNOWN_BOT_IDS = frozenset(spec.id for spec in BOT_REGISTRY)

# alias (lowercase, no "@") -> canonical bot id.
BOT_ALIASES: dict[str, str] = {
    alias: spec.id for spec in BOT_REGISTRY for alias in spec.aliases
}

# Canonical bot ids that must receive a non-empty cwd on invoke.
BOTS_REQUIRING_CWD = frozenset(spec.id for spec in BOT_REGISTRY if spec.requires_cwd)


def bot_requires_cwd(bot_id: str) -> bool:
    return bot_id in BOTS_REQUIRING_CWD


def bot_registry_payload() -> list[dict]:
    """JSON-serializable registry sent to Dart on connect (see `ready`
    envelope) so it can derive its own @tag matching and capability flags."""
    return [
        {
            "id": spec.id,
            "aliases": sorted(spec.aliases),
            "requires_cwd": spec.requires_cwd,
        }
        for spec in BOT_REGISTRY
    ]


HOST = "127.0.0.1"
PORT = 8765
