"""Wire protocol constants for the Dart <-> Python WebSocket connection.

Envelopes are flat JSON objects with a "type" field. Every message-bearing
envelope carries message_id/parent_message_id/bot_id so the message tree
can be built without changing this shape later.

`user_message.context` is the column's visible linear history through the
reply target (inclusive), as Stitch nodes — not a Completions messages[].
Projection to runtime formats happens inside adapters.
"""

READY = "ready"
USER_MESSAGE = "user_message"
MESSAGE_START = "message_start"
MESSAGE_END = "message_end"
ERROR = "error"

DEFAULT_BOT_ID = "chatgpt"
DEFAULT_MODEL = "gpt-4o-mini"

# Local bot ids the bridge currently knows how to dispatch.
KNOWN_BOT_IDS = frozenset({DEFAULT_BOT_ID, "openai"})

HOST = "127.0.0.1"
PORT = 8765
