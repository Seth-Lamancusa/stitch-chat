"""Prove chdir-before-launch_bridge makes agent pwd match target cwd."""

from __future__ import annotations

import asyncio
import os
from pathlib import Path

from cursor_sdk import AsyncClient, LocalAgentOptions
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[3] / ".env")

PROCESS = Path(__file__).resolve().parent
TARGET = Path.home()


async def main() -> None:
    os.chdir(PROCESS)
    print(f"started_in={os.getcwd()}")
    os.chdir(TARGET)
    print(f"chdir_to={os.getcwd()}")
    async with await AsyncClient.launch_bridge(
        workspace=str(TARGET),
        local=LocalAgentOptions(cwd=str(TARGET)),
    ) as client:
        agent = await client.create_agent(
            model="composer-2.5",
            local=LocalAgentOptions(cwd=str(TARGET)),
        )
        try:
            result = await (
                await agent.send(
                    "Run `pwd` and reply with exactly one line: CWD=<that absolute path>"
                )
            ).wait()
            print(f"status={result.status}")
            print(f"text={result.result!r}")
            assert str(TARGET) in (result.result or ""), result.result
        finally:
            await agent.close()
    print("CHDIR_OK")


if __name__ == "__main__":
    asyncio.run(main())
