# Runbook

## Start Here

Open PowerShell 7 on Windows in the repo root.

## Validate the Host

```powershell
pwsh -File .\scripts\Test-HostPrereqs.ps1
```

Expected result:

- A pass/fail table prints to the console.
- [`artifacts/host-health.json`](../artifacts/host-health.json) is refreshed.

Rollback note:

- None required. This workflow is read-mostly and only refreshes the generated report file.

## Create Local Config Files

```powershell
pwsh -File .\scripts\New-LabEnv.ps1
```

Expected result:

- `.env.local` exists if it did not already exist.
- `configs/lab.config.json` exists if it did not already exist.

Rollback note:

- Delete `.env.local` and `configs/lab.config.json`.

## Run the One-Command Demo

```powershell
pwsh -File .\scripts\Invoke-Demo.ps1
```

Expected result in under five minutes:

- Host prerequisites are validated.
- `compose.yaml` starts the synthetic health service.
- PowerShell waits for `http://127.0.0.1:8088/health`.
- WSL runs the demo helper.
- `artifacts/lab-summary.json` and `artifacts/lab-state.db` are updated.
- Docker Compose is stopped automatically unless `-KeepServiceUp` is used.

Rollback note:

- Delete `artifacts/lab-summary.json`, `artifacts/lab-state.db`, and `artifacts/host-health.json`.
- If you used `-KeepServiceUp`, run `docker compose down --remove-orphans`.

## Run Linux-Side Tasks Manually

Inside WSL Ubuntu:

```bash
make validate
make demo
make test
```

Rollback note:

- `make demo`: remove `artifacts/lab-summary.json` and `artifacts/lab-state.db`.
- `make install`: remove `.venv` or uninstall the editable package.

## Stop the Lab

If the demo was left running:

```powershell
docker compose down --remove-orphans
```

Then remove generated artifacts if you want a clean slate:

```powershell
Remove-Item .\artifacts\lab-state.db, .\artifacts\lab-summary.json, .\artifacts\host-health.json -ErrorAction SilentlyContinue
```
