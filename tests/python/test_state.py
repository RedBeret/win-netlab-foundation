from __future__ import annotations

from pathlib import Path

from win_netlab_foundation.models import LabConfig, Device
from win_netlab_foundation.state import connect_database, fetch_hostnames, record_demo_run, upsert_devices


def build_config() -> LabConfig:
    return LabConfig(
        lab_name="win-netlab-foundation",
        operator="lab-operator",
        environment="local-training",
        documentation_ranges=("192.0.2.0/24",),
        devices=(
            Device(
                hostname="edge-a.lab.example",
                role="edge",
                platform="synthetic-iosxe",
                management_ip="192.0.2.10",
                serial="FTX0000LAB01",
                username="lab-operator",
            ),
        ),
    )


def test_database_is_created_and_upserted(tmp_path: Path) -> None:
    db_path = tmp_path / "lab-state.db"
    with connect_database(db_path) as connection:
        upsert_devices(connection, build_config())
        assert fetch_hostnames(connection) == ["edge-a.lab.example"]


def test_record_demo_run_is_idempotent(tmp_path: Path) -> None:
    db_path = tmp_path / "lab-state.db"
    report_path = tmp_path / "lab-summary.json"
    config = build_config()

    with connect_database(db_path) as connection:
        upsert_devices(connection, config)
        record_demo_run(
            connection,
            run_id="demo-001",
            generated_at="2026-03-11T12:00:00+00:00",
            config=config,
            probe_url="http://127.0.0.1:8088/health",
            probe_status="healthy",
            report_path=report_path,
        )
        record_demo_run(
            connection,
            run_id="demo-001",
            generated_at="2026-03-11T12:00:00+00:00",
            config=config,
            probe_url="http://127.0.0.1:8088/health",
            probe_status="healthy",
            report_path=report_path,
        )

        cursor = connection.execute("SELECT COUNT(*) FROM demo_runs;")
        assert cursor.fetchone()[0] == 1

