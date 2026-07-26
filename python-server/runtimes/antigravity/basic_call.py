"""Minimal call/response smoke test for the Google Antigravity SDK.

Run with this directory's venv (not the top-level python-server venv):
    ./venv/bin/python basic_call.py "your prompt here"

Requires GEMINI_API_KEY, either already exported or set in a .env file
anywhere above this script (e.g. the repo root).
"""

import asyncio
import sys

from dotenv import find_dotenv, load_dotenv
from google.antigravity import Agent, LocalAgentConfig

load_dotenv(find_dotenv())


async def main(prompt: str) -> None:
    config = LocalAgentConfig()
    async with Agent(config) as agent:
        response = await agent.chat(prompt)
        print(await response.text())


if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Say hello in one sentence."
    asyncio.run(main(prompt))
