from __future__ import annotations

from dataclasses import asdict
from datetime import datetime, timezone
import json
from pathlib import Path
import time
from typing import Any
from urllib import error, request
from uuid import uuid4

from .logging_utils import log_event
from .models import LabConfig, load_lab_config
from .state import connect_database, record_demo_run, upsert_devices


def probe_health(url: str, *, max_attempts: int = 5, timeout_seconds: int = 5, log_path: Path | None = None) -> dict[str, Any]:
    last_error = ""
    for attempt in range(1, max_attempts + 1):
        try:
            with request.urlopen(url, timeout=timeout_seconds) as response:
                payload = json.loads(response.read().decode("utf-8"))
                result = {
                    "success": response.status == 200,
                    "status_code": response.status,
                    "payload": payload,
                    "attempts": attempt,
                }
                if log_path:
                    log_event(log_path, "INFO", "demo.probe", "Synthetic health probe succeeded.", attempt=attempt, status_code=response.status)
                return result
        except (error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = str(exc)
            if log_path:
                log_event(log_path, "WARN", "demo.probe", "Synthetic health probe failed.", attempt=attempt, error=last_error)
            if attempt < max_attempts:
                time.sleep(2 ** (attempt - 1))

    return {
        "success": False,
        "status_code": None,
        "payload": None,
        "attempts": max_attempts,
        "error": last_error or "probe failed",
    }


def build_summary(config: LabConfig, *, probe_result: dict[str, Any], report_path: Path, db_path: Path) -> dict[str, Any]:
    timestamp = datetime.now(timezone.utc).isoformat()
    return {
        "generated_at": timestamp,
        "status": "pass" if probe_result.get("success", True) else "fail",
        "lab_name": config.lab_name,
        "operator": config.operator,
        "environment": config.environment,
        "device_count": len(config.devices),
        "devices": [asdict(device) for device in config.devices],
        "documentation_ranges": list(config.documentation_ranges),
        "probe": probe_result,
        "artifacts": {
            "report_path": str(report_path),
            "db_path": str(db_path),
        },
        "what_this_teaches": [
            "How Windows PowerShell can orchestrate WSL and Docker without crossing trust boundaries.",
            "How to validate synthetic inventories before later automation labs reuse them.",
            "How to keep lab state idempotent with structured logging and SQLite snapshots.",
        ],
        "rollback": "Delete artifacts/lab-state.db and artifacts/lab-summary.json to reset the Python-side demo state.",
    }


def run_demo(
    *,
    config_path: Path,
    db_path: Path,
    report_path: Path,
    probe_url: str | None = None,
    log_path: Path | None = None,
) -> dict[str, Any]:
    config = load_lab_config(config_path)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    if log_path:
        log_event(log_path, "INFO", "demo.start", "Python demo execution started.", config=str(config_path), db=str(db_path))

    probe_result = {"success": True, "status_code": None, "payload": None, "attempts": 0}
    if probe_url:
        probe_result = probe_health(probe_url, log_path=log_path)

    run_id = str(uuid4())
    generated_at = datetime.now(timezone.utc).isoformat()

    with connect_database(db_path) as connection:
        upsert_devices(connection, config)
        record_demo_run(
            connection,
            run_id=run_id,
            generated_at=generated_at,
            config=config,
            probe_url=probe_url,
            probe_status="healthy" if probe_result.get("success", False) else "unhealthy",
            report_path=report_path,
        )

    summary = build_summary(config, probe_result=probe_result, report_path=report_path, db_path=db_path)
    with report_path.open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2)

    if log_path:
        log_event(log_path, "INFO", "demo.finish", "Python demo execution finished.", status=summary["status"], report=str(report_path))

    return summary

