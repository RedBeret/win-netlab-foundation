from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Iterable

from .models import LabConfig


SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
    hostname TEXT PRIMARY KEY,
    role TEXT NOT NULL,
    platform TEXT NOT NULL,
    management_ip TEXT NOT NULL UNIQUE,
    serial TEXT NOT NULL,
    username TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS demo_runs (
    run_id TEXT PRIMARY KEY,
    generated_at TEXT NOT NULL,
    lab_name TEXT NOT NULL,
    operator TEXT NOT NULL,
    probe_url TEXT,
    probe_status TEXT NOT NULL,
    device_count INTEGER NOT NULL,
    report_path TEXT NOT NULL
);
"""


def connect_database(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(db_path)
    connection.executescript(SCHEMA)
    return connection


def upsert_devices(connection: sqlite3.Connection, config: LabConfig) -> None:
    connection.executemany(
        """
        INSERT INTO devices (hostname, role, platform, management_ip, serial, username)
        VALUES (:hostname, :role, :platform, :management_ip, :serial, :username)
        ON CONFLICT(hostname) DO UPDATE SET
            role = excluded.role,
            platform = excluded.platform,
            management_ip = excluded.management_ip,
            serial = excluded.serial,
            username = excluded.username;
        """,
        [
            {
                "hostname": device.hostname,
                "role": device.role,
                "platform": device.platform,
                "management_ip": device.management_ip,
                "serial": device.serial,
                "username": device.username,
            }
            for device in config.devices
        ],
    )
    connection.commit()


def record_demo_run(
    connection: sqlite3.Connection,
    *,
    run_id: str,
    generated_at: str,
    config: LabConfig,
    probe_url: str | None,
    probe_status: str,
    report_path: Path,
) -> None:
    connection.execute(
        """
        INSERT OR REPLACE INTO demo_runs (
            run_id,
            generated_at,
            lab_name,
            operator,
            probe_url,
            probe_status,
            device_count,
            report_path
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """,
        (
            run_id,
            generated_at,
            config.lab_name,
            config.operator,
            probe_url,
            probe_status,
            len(config.devices),
            str(report_path),
        ),
    )
    connection.commit()


def fetch_hostnames(connection: sqlite3.Connection) -> list[str]:
    cursor = connection.execute("SELECT hostname FROM devices ORDER BY hostname;")
    return [row[0] for row in cursor.fetchall()]

