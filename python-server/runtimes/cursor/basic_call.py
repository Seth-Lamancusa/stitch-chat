"""Minimal call/response smoke test for the Cursor Python SDK.

Run with this directory's venv (not the top-level python-server venv):
    ./venv/bin/python basic_call.py "your prompt here"

Requires CURSOR_API_KEY, either already exported or set in a .env file
anywhere above this script (e.g. the repo root).
"""

import asyncio
import sys

from cursor_sdk import AsyncAgent, AsyncClient, LocalAgentOptions
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())


async def main(prompt: str) -> None:
    # launch_bridge spawns the local `cursor-sdk-bridge` subprocess and wires
    # the client to it; CURSOR_API_KEY is read by the bridge itself.
    async with await AsyncClient.launch_bridge() as client:
        agent = await AsyncAgent.create(
            client=client,
            model="composer-2.5",
            local=LocalAgentOptions(cwd="."),
        )
        try:
            run = await agent.send(prompt)
            print(await run.text())
        finally:
            await agent.close()


if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Say hello in one sentence."
    asyncio.run(main(prompt))
