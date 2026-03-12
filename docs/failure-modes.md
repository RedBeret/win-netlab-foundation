# Failure Modes

## Common Problems

| Symptom | Likely Cause | Remediation |
| --- | --- | --- |
| `PowerShell 7+` fails | The shell is Windows PowerShell 5.1 instead of PowerShell 7 | Launch `pwsh` and rerun the scripts. |
| `WSL present` fails | WSL is not enabled | Enable WSL, install Ubuntu, then rerun `scripts/Test-WslState.ps1`. |
| `Ubuntu available in WSL` fails | WSL exists but Ubuntu is not installed | Install an Ubuntu distro and rerun the check. |
| `Python 3 available in WSL` fails | `python3` is missing inside Ubuntu | Install Python inside Ubuntu, then rerun the check. |
| `Docker Desktop running` fails | Docker Desktop is stopped or not using the Linux backend | Start Docker Desktop and confirm the WSL backend is enabled. |
| Demo hangs on the health probe | Port `8088` is already in use or the container failed to start | Run `docker compose ps`, free port `8088`, then rerun `Invoke-Demo.ps1`. |
| `make demo` fails in WSL | `make` is missing or Python cannot find the package | Install `make` in Ubuntu or let the script use the Python fallback. |
| Config validation fails | A hostname, username, serial, or IP stopped being synthetic | Update `configs/lab.config.json` to use `.lab.example`, RFC5737 IPs, and fake IDs only. |
| SQLite file looks stale | A previous demo run already created `artifacts/lab-state.db` | Delete the DB file and rerun the demo for a clean state. |

## Reading the Health Report

The host report at [`artifacts/host-health.json`](../artifacts/host-health.json) is the first place to look when the demo stops early.

The most useful fields are:

- `overall_status`
- `checks[].name`
- `checks[].status`
- `checks[].message`

## Log Locations

- PowerShell logs: `artifacts/logs/session-YYYYMMDD.jsonl`
- Python logs: `artifacts/logs/python-session.jsonl`
