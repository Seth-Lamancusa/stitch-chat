"""Minimal call/response smoke test for the OpenAI Codex SDK.

Run with this directory's venv (not the top-level python-server venv):
    ./venv/bin/python basic_call.py "your prompt here"

Requires the Codex CLI to be logged in (`codex login`) or an API key set
via login_api_key(); the SDK shells out to the bundled Codex CLI runtime.
Also loads a .env file anywhere above this script (e.g. the repo root),
in case OPENAI_API_KEY is needed there.
"""

import asyncio
import sys

from dotenv import find_dotenv, load_dotenv
from openai_codex import AsyncCodex

load_dotenv(find_dotenv())


async def main(prompt: str) -> None:
    codex = AsyncCodex()
    try:
        thread = await codex.thread_start()
        result = await thread.run(prompt)
        print(result.final_response)
    finally:
        await codex.close()


if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Say hello in one sentence."
    asyncio.run(main(prompt))
