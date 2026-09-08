"""Live miss/hit/fork smoke against agent_runner NDJSON loop."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PY = str(ROOT / "venv" / "bin" / "python")
RUNNER = str(ROOT / "agent_runner.py")
CWD = str(ROOT.parents[2])


def main() -> None:
    proc = subprocess.Popen(
        [PY, RUNNER],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    assert proc.stdin and proc.stdout

    def invoke(req: dict) -> dict:
        proc.stdin.write(json.dumps(req) + "\n")
        proc.stdin.flush()
        line = proc.stdout.readline()
        if not line:
            err = proc.stderr.read()
            raise SystemExit(f"no stdout; stderr={err!r} rc={proc.poll()}")
        return json.loads(line)

    r1 = invoke(
        {
            "id": 1,
            "cwd": CWD,
            "assistant_message_id": "bot-1",
            "context": [
                {
                    "id": "u1",
                    "role": "user",
                    "author_id": "",
                    "content": "Reply with exactly: miss-ok",
                },
            ],
        }
    )
    print("MISS", {k: r1.get(k) for k in ("ok", "mode", "text", "agent_id")})
    assert r1["ok"] and r1["mode"] == "miss", r1

    r2 = invoke(
        {
            "id": 2,
            "cwd": CWD,
            "assistant_message_id": "bot-2",
            "context": [
                {
                    "id": "u1",
                    "role": "user",
                    "author_id": "",
                    "content": "Reply with exactly: miss-ok",
                },
                {
                    "id": "bot-1",
                    "role": "localBot",
                    "author_id": "cursor",
                    "content": r1["text"],
                },
                {
                    "id": "u2",
                    "role": "user",
                    "author_id": "",
                    "content": "Reply with exactly: hit-ok",
                },
            ],
        }
    )
    print("HIT", {k: r2.get(k) for k in ("ok", "mode", "text", "agent_id")})
    assert r2["ok"] and r2["mode"] == "hit", r2
    assert r2["agent_id"] == r1["agent_id"], (r1["agent_id"], r2["agent_id"])

    r3 = invoke(
        {
            "id": 3,
            "cwd": CWD,
            "assistant_message_id": "bot-3",
            "context": [
                {
                    "id": "u1",
                    "role": "user",
                    "author_id": "",
                    "content": "Reply with exactly: miss-ok",
                },
                {
                    "id": "u3",
                    "role": "user",
                    "author_id": "",
                    "content": "Reply with exactly: fork-ok",
                },
            ],
        }
    )
    print("FORK", {k: r3.get(k) for k in ("ok", "mode", "text", "agent_id")})
    assert r3["ok"] and r3["mode"] == "miss", r3
    assert r3["agent_id"] != r1["agent_id"], (r3["agent_id"], r1["agent_id"])

    proc.stdin.close()
    proc.wait(timeout=60)
    print("ALL_OK")


if __name__ == "__main__":
    main()
