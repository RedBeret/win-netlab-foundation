from __future__ import annotations

import json
from pathlib import Path

import pytest

from win_netlab_foundation.models import ConfigValidationError, load_lab_config, validate_lab_config


def test_validate_lab_config_accepts_synthetic_ranges() -> None:
    payload = {
        "lab_name": "win-netlab-foundation",
        "operator": "lab-operator",
        "environment": "local-training",
        "documentation_ranges": ["192.0.2.0/24"],
        "devices": [
            {
                "hostname": "edge-a.lab.example",
                "role": "edge",
                "platform": "synthetic-iosxe",
                "management_ip": "192.0.2.10",
                "serial": "FTX0000LAB01",
                "username": "lab-operator",
            }
        ],
    }

    config = validate_lab_config(payload)
    assert config.devices[0].management_ip == "192.0.2.10"


def test_validate_lab_config_rejects_non_documentation_ip() -> None:
    payload = {
        "lab_name": "win-netlab-foundation",
        "operator": "lab-operator",
        "environment": "local-training",
        "documentation_ranges": ["192.0.2.0/24"],
        "devices": [
            {
                "hostname": "edge-a.lab.example",
                "role": "edge",
                "platform": "synthetic-iosxe",
                "management_ip": "10.0.0.10",
                "serial": "FTX0000LAB01",
                "username": "lab-operator",
            }
        ],
    }

    with pytest.raises(ConfigValidationError):
        validate_lab_config(payload)


def test_validate_lab_config_rejects_ip_outside_declared_ranges() -> None:
    payload = {
        "lab_name": "win-netlab-foundation",
        "operator": "lab-operator",
        "environment": "local-training",
        "documentation_ranges": ["192.0.2.0/24"],
        "devices": [
            {
                "hostname": "edge-a.lab.example",
                "role": "edge",
                "platform": "synthetic-iosxe",
                "management_ip": "198.51.100.10",
                "serial": "FTX0000LAB01",
                "username": "lab-operator",
            }
        ],
    }

    with pytest.raises(ConfigValidationError):
        validate_lab_config(payload)


def test_load_lab_config_reads_example_file(tmp_path: Path) -> None:
    config_path = tmp_path / "lab.config.json"
    payload = {
        "lab_name": "win-netlab-foundation",
        "operator": "lab-operator",
        "environment": "local-training",
        "documentation_ranges": ["192.0.2.0/24"],
        "devices": [
            {
                "hostname": "edge-a.lab.example",
                "role": "edge",
                "platform": "synthetic-iosxe",
                "management_ip": "192.0.2.10",
                "serial": "FTX0000LAB01",
                "username": "lab-operator",
            }
        ],
    }
    config_path.write_text(json.dumps(payload), encoding="utf-8")

    config = load_lab_config(config_path)
    assert config.lab_name == "win-netlab-foundation"
