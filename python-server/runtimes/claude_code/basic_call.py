"""Minimal call/response smoke test for the Claude Agent SDK.

Run with this directory's venv (not the top-level python-server venv):
    ./venv/bin/python basic_call.py "your prompt here"

Requires ANTHROPIC_API_KEY, either already exported or set in a .env file
anywhere above this script (e.g. the repo root).
"""

import asyncio
import sys

from claude_agent_sdk import ClaudeAgentOptions, ResultMessage, query
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())


async def main(prompt: str) -> None:
    async for message in query(
        prompt=prompt,
        options=ClaudeAgentOptions(allowed_tools=[]),
    ):
        if isinstance(message, ResultMessage):
            print(message.result)


if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Say hello in one sentence."
    asyncio.run(main(prompt))
