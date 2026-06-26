"""Logging setup for Lumina applications."""

from __future__ import annotations

import logging as std_logging
from datetime import datetime
from pathlib import Path

from .state import ensure_state_dir


def log_path(app_name: str) -> Path:
    safe_name = app_name.replace("/", "-").replace(" ", "-")
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return ensure_state_dir("logs") / f"{safe_name}-{stamp}.log"


def get_logger(app_name: str, level: int = std_logging.INFO) -> std_logging.Logger:
    logger = std_logging.getLogger(app_name)
    logger.setLevel(level)
    logger.propagate = False
    if logger.handlers:
        return logger

    formatter = std_logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    stderr_handler = std_logging.StreamHandler()
    stderr_handler.setFormatter(formatter)
    logger.addHandler(stderr_handler)

    try:
        file_handler = std_logging.FileHandler(log_path(app_name), encoding="utf-8")
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    except OSError as exc:
        logger.warning("Could not create Lumina log file: %s", exc)

    return logger

