"""Minimal call/response smoke test for the Cursor Python SDK.

Run with this directory's venv (not the top-level python-server venv):
    ./venv/bin/python basic_call.py "your prompt here"

Requires CURSOR_API_KEY, either already exported or set in a .env file
anywhere above this script (e.g. the repo root).
"""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

from cursor_sdk import AsyncClient, CursorAgentError, LocalAgentOptions
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())


async def main(prompt: str) -> None:
    cwd = str(Path(__file__).resolve().parents[3])  # repo root
    api_key = os.environ.get("CURSOR_API_KEY")
    if not api_key:
        raise SystemExit("CURSOR_API_KEY not set")

    # launch_bridge spawns the local `cursor-sdk-bridge` subprocess and wires
    # the client to it. Align workspace with cwd so local resume/list resolve.
    # API key comes from CURSOR_API_KEY in the environment (no launch kwarg).
    async with await AsyncClient.launch_bridge(workspace=cwd) as client:
        async with await client.create_agent(
            model="composer-2.5",
            api_key=api_key,
            local=LocalAgentOptions(cwd=cwd),
        ) as agent:
            agent_id = getattr(agent, "agent_id", None) or getattr(agent, "id", None)
            print(f"agent_id={agent_id}")
            try:
                run = await agent.send(prompt)
                result = await run.wait()
            except CursorAgentError as err:
                print(
                    f"startup failed: {err.message} retryable={err.is_retryable}",
                    file=sys.stderr,
                )
                raise SystemExit(1) from err

            print(f"status={result.status}")
            print(f"text={result.result!r}")
            print(f"usage={result.usage!r}")
            if result.status != "finished":
                raise SystemExit(2)


if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Say hello in one sentence."
    asyncio.run(main(prompt))
