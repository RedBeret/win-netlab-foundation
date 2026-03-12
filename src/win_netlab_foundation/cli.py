from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from .demo import run_demo
from .logging_utils import log_event
from .models import ConfigValidationError, load_lab_config

try:
    import typer

    TYPER_AVAILABLE = True
except ImportError:  # pragma: no cover - runtime fallback for zero-dependency demo mode
    typer = None  # type: ignore[assignment]
    TYPER_AVAILABLE = False


DEFAULT_LOG_PATH = Path("artifacts/logs/python-session.jsonl")


def _validate_impl(config: Path) -> dict[str, object]:
    lab_config = load_lab_config(config)
    return {
        "status": "pass",
        "lab_name": lab_config.lab_name,
        "device_count": len(lab_config.devices),
    }


def _demo_impl(config: Path, db: Path, report: Path, probe_url: str | None, log_path: Path) -> dict[str, object]:
    return run_demo(config_path=config, db_path=db, report_path=report, probe_url=probe_url, log_path=log_path)


if TYPER_AVAILABLE:
    app = typer.Typer(add_completion=False, help="Local helpers for the win-netlab-foundation training repo.")

    @app.command()
    def validate(config: Path = typer.Option(Path("configs/lab.config.json"), exists=True, file_okay=True, dir_okay=False)) -> None:
        result = _validate_impl(config)
        typer.echo(json.dumps(result, indent=2))

    @app.command()
    def demo(
        config: Path = typer.Option(Path("configs/lab.config.json")),
        db: Path = typer.Option(Path("artifacts/lab-state.db")),
        report: Path = typer.Option(Path("artifacts/lab-summary.json")),
        probe_url: str | None = typer.Option(None),
        log_path: Path = typer.Option(DEFAULT_LOG_PATH),
    ) -> None:
        result = _demo_impl(config, db, report, probe_url, log_path)
        typer.echo(json.dumps(result, indent=2))


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="win-netlab", description="Synthetic training helpers for win-netlab-foundation.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate", help="Validate the synthetic lab config.")
    validate_parser.add_argument("--config", default="configs/lab.config.json")

    demo_parser = subparsers.add_parser("demo", help="Run the local synthetic demo.")
    demo_parser.add_argument("--config", default="configs/lab.config.json")
    demo_parser.add_argument("--db", default="artifacts/lab-state.db")
    demo_parser.add_argument("--report", default="artifacts/lab-summary.json")
    demo_parser.add_argument("--probe-url", default=None)
    demo_parser.add_argument("--log-path", default=str(DEFAULT_LOG_PATH))
    return parser


def run(argv: Sequence[str] | None = None) -> int:
    try:
        if TYPER_AVAILABLE:
            app(prog_name="win-netlab", args=list(argv) if argv is not None else None, standalone_mode=False)
            return 0

        parser = _build_parser()
        args = parser.parse_args(argv)
        if args.command == "validate":
            result = _validate_impl(Path(args.config))
            print(json.dumps(result, indent=2))
            return 0

        if args.command == "demo":
            result = _demo_impl(Path(args.config), Path(args.db), Path(args.report), args.probe_url, Path(args.log_path))
            print(json.dumps(result, indent=2))
            return 0

        parser.error(f"Unknown command: {args.command}")
    except ConfigValidationError as exc:
        log_event(DEFAULT_LOG_PATH, "ERROR", "cli.validation", "Validation failed.", error=str(exc))
        print(json.dumps({"status": "fail", "error": str(exc)}, indent=2))
        return 1
    except Exception as exc:  # pragma: no cover - defensive CLI boundary
        log_event(DEFAULT_LOG_PATH, "ERROR", "cli.unhandled", "Unhandled CLI error.", error=str(exc))
        print(json.dumps({"status": "fail", "error": str(exc)}, indent=2))
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(run())
