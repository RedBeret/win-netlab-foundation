from __future__ import annotations

from dataclasses import dataclass
from ipaddress import ip_address, ip_network
from pathlib import Path
import json
import re
from typing import Any

try:
    from pydantic import BaseModel, Field, ValidationError, field_validator

    PYDANTIC_AVAILABLE = True
except ImportError:  # pragma: no cover - runtime fallback for zero-dependency demo mode
    BaseModel = object  # type: ignore[assignment]
    Field = None  # type: ignore[assignment]
    ValidationError = ValueError  # type: ignore[assignment]
    PYDANTIC_AVAILABLE = False


RFC5737_NETWORKS = (
    ip_network("192.0.2.0/24"),
    ip_network("198.51.100.0/24"),
    ip_network("203.0.113.0/24"),
)
HOSTNAME_PATTERN = re.compile(r"^[a-z0-9-]+\.lab\.example$")
USERNAME_PATTERN = re.compile(r"^[a-z][a-z0-9-]+$")
SERIAL_PATTERN = re.compile(r"^[A-Z0-9-]{8,}$")
ROLE_SET = {"edge", "core", "access"}


class ConfigValidationError(ValueError):
    """Raised when a synthetic lab config is invalid."""


@dataclass(frozen=True)
class Device:
    hostname: str
    role: str
    platform: str
    management_ip: str
    serial: str
    username: str


@dataclass(frozen=True)
class LabConfig:
    lab_name: str
    operator: str
    environment: str
    documentation_ranges: tuple[str, ...]
    devices: tuple[Device, ...]


if PYDANTIC_AVAILABLE:
    class DeviceSchema(BaseModel):
        hostname: str = Field(min_length=5)
        role: str
        platform: str = Field(min_length=3)
        management_ip: str
        serial: str
        username: str

        @field_validator("hostname")
        @classmethod
        def validate_hostname(cls, value: str) -> str:
            validate_hostname(value)
            return value

        @field_validator("role")
        @classmethod
        def validate_role(cls, value: str) -> str:
            validate_role(value)
            return value

        @field_validator("management_ip")
        @classmethod
        def validate_management_ip(cls, value: str) -> str:
            validate_documentation_ip(value)
            return value

        @field_validator("serial")
        @classmethod
        def validate_serial_value(cls, value: str) -> str:
            validate_serial(value)
            return value

        @field_validator("username")
        @classmethod
        def validate_username_value(cls, value: str) -> str:
            validate_username(value)
            return value


    class LabConfigSchema(BaseModel):
        lab_name: str = Field(min_length=3)
        operator: str
        environment: str
        documentation_ranges: list[str]
        devices: list[DeviceSchema]

        @field_validator("operator")
        @classmethod
        def validate_operator(cls, value: str) -> str:
            validate_username(value)
            return value


def validate_hostname(value: str) -> None:
    if not HOSTNAME_PATTERN.match(value):
        raise ConfigValidationError(f"Hostname '{value}' must end with .lab.example and stay synthetic.")


def validate_role(value: str) -> None:
    if value not in ROLE_SET:
        raise ConfigValidationError(f"Role '{value}' must be one of {sorted(ROLE_SET)}.")


def validate_documentation_ip(value: str) -> None:
    address = ip_address(value)
    if not any(address in network for network in RFC5737_NETWORKS):
        raise ConfigValidationError(f"IP '{value}' must be inside an RFC5737 documentation range.")


def validate_documentation_range(value: str) -> None:
    network = ip_network(value, strict=False)
    if not any(network.subnet_of(documentation_network) for documentation_network in RFC5737_NETWORKS):
        raise ConfigValidationError(f"Range '{value}' must be inside an RFC5737 documentation range.")


def validate_serial(value: str) -> None:
    if not SERIAL_PATTERN.match(value):
        raise ConfigValidationError(f"Serial '{value}' must be uppercase synthetic text.")


def validate_username(value: str) -> None:
    if not USERNAME_PATTERN.match(value):
        raise ConfigValidationError(f"Username '{value}' must be synthetic lowercase text.")


def _manual_validate(payload: dict[str, Any]) -> LabConfig:
    required_keys = {"lab_name", "operator", "environment", "documentation_ranges", "devices"}
    missing_keys = sorted(required_keys - payload.keys())
    if missing_keys:
        raise ConfigValidationError(f"Missing required keys: {', '.join(missing_keys)}")

    validate_username(str(payload["operator"]))
    documentation_ranges = tuple(str(item) for item in payload["documentation_ranges"])
    declared_networks = tuple(ip_network(item, strict=False) for item in documentation_ranges)
    for documentation_range in documentation_ranges:
        validate_documentation_range(documentation_range)
    devices_payload = payload["devices"]
    if not isinstance(devices_payload, list) or not devices_payload:
        raise ConfigValidationError("devices must be a non-empty list.")

    devices: list[Device] = []
    seen_hostnames: set[str] = set()
    seen_ips: set[str] = set()
    for item in devices_payload:
        hostname = str(item["hostname"])
        role = str(item["role"])
        platform = str(item["platform"])
        management_ip = str(item["management_ip"])
        serial = str(item["serial"])
        username = str(item["username"])

        validate_hostname(hostname)
        validate_role(role)
        validate_documentation_ip(management_ip)
        validate_serial(serial)
        validate_username(username)
        if not any(ip_address(management_ip) in network for network in declared_networks):
            raise ConfigValidationError(f"IP '{management_ip}' is not inside the declared documentation ranges.")

        if hostname in seen_hostnames:
            raise ConfigValidationError(f"Duplicate hostname '{hostname}' is not allowed.")
        if management_ip in seen_ips:
            raise ConfigValidationError(f"Duplicate management IP '{management_ip}' is not allowed.")

        seen_hostnames.add(hostname)
        seen_ips.add(management_ip)
        devices.append(
            Device(
                hostname=hostname,
                role=role,
                platform=platform,
                management_ip=management_ip,
                serial=serial,
                username=username,
            )
        )

    return LabConfig(
        lab_name=str(payload["lab_name"]),
        operator=str(payload["operator"]),
        environment=str(payload["environment"]),
        documentation_ranges=documentation_ranges,
        devices=tuple(devices),
    )


def validate_lab_config(payload: dict[str, Any]) -> LabConfig:
    if PYDANTIC_AVAILABLE:
        try:
            schema = LabConfigSchema.model_validate(payload)
        except ValidationError as exc:  # pragma: no cover - depends on optional package
            raise ConfigValidationError(str(exc)) from exc
        payload = schema.model_dump()
    return _manual_validate(payload)


def load_lab_config(config_path: Path) -> LabConfig:
    with config_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    return validate_lab_config(payload)
