"""Live create→resume smoke. Run: ./venv/bin/python smoke_resume.py"""

from __future__ import annotations

import asyncio
from pathlib import Path

from cursor_sdk import AsyncClient, LocalAgentOptions
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())


async def main() -> None:
    cwd = str(Path(__file__).resolve().parents[3])
    print("launch", flush=True)
    async with await AsyncClient.launch_bridge(workspace=cwd) as client:
        agent = await client.create_agent(
            model="composer-2.5",
            local=LocalAgentOptions(cwd=cwd),
        )
        agent_id = agent.agent_id
        print(f"agent={agent_id}", flush=True)
        try:
            result = await (await agent.send("Reply with exactly: A")).wait()
            print(f"1 status={result.status} text={result.result!r}", flush=True)
        finally:
            await agent.close()

        print("resume…", flush=True)
        agent2 = await client.resume_agent(agent_id, {"model": "composer-2.5"})
        try:
            result2 = await (
                await agent2.send("Reply with exactly: B", {"model": "composer-2.5"})
            ).wait()
            print(f"2 status={result2.status} text={result2.result!r}", flush=True)
        finally:
            await agent2.close()
    print("DONE", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
