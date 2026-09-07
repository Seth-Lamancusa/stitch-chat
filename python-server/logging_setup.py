"""Loguru setup for the Stitch Python bridge.

Respects the same env knobs as Dart:
  STITCH_LOG_LEVEL  TRACE|DEBUG|INFO|WARNING|ERROR  (default DEBUG)
  STITCH_LOG_DIR    directory for python.log         (default ./logs)

Pipeline breadcrumbs use a greppable ``hop=<stage> | …`` prefix via [hop]:
  py.ws → py.server → py.adapter → py.runtime (and reverse on the way back).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from loguru import logger

_CONFIGURED = False


def configure_logging() -> None:
    """Idempotent: stderr + rotating ``python.log`` under STITCH_LOG_DIR."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    level = (os.environ.get("STITCH_LOG_LEVEL") or "DEBUG").strip().upper()
    if level == "WARN":
        level = "WARNING"

    log_dir = Path(os.environ.get("STITCH_LOG_DIR") or "logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / "python.log"

    logger.remove()
    logger.add(
        sys.stderr,
        level=level,
        format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level:<7} | {name}:{function}:{line} | {message}",
    )
    logger.add(
        log_file,
        level=level,
        rotation="10 MB",
        retention=5,
        encoding="utf-8",
        format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level:<7} | {name}:{function}:{line} | {message}",
    )
    logger.info("logging configured level={} file={}", level, log_file)
    _CONFIGURED = True


def hop(stage: str, message: str, *args: object) -> None:
    """DEBUG breadcrumb: ``hop=<stage> | message`` (scannable across the stack)."""
    logger.debug("hop={} | " + message, stage, *args)
