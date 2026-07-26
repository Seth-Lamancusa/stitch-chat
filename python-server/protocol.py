"""Wire protocol constants for the Dart <-> Python WebSocket connection.

Envelopes are flat JSON objects with a "type" field. Every message-bearing
envelope carries message_id/parent_message_id/bot_id so the eventual message
tree (see project README) can be built without changing this shape later.
"""

READY = "ready"
USER_MESSAGE = "user_message"
MESSAGE_START = "message_start"
MESSAGE_END = "message_end"
ERROR = "error"

DEFAULT_BOT_ID = "openai-default"
DEFAULT_MODEL = "gpt-4o-mini"

HOST = "127.0.0.1"
PORT = 8765
