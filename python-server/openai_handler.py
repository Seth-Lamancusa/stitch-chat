"""Backward-compatible import path — prefer openai_compatible. """

from openai_compatible import project_context, stream_reply

__all__ = ["project_context", "stream_reply"]
