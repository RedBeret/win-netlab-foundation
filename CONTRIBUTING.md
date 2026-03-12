# Contributing

Thanks for contributing to `win-netlab-foundation`.

This repo is intentionally narrow. It teaches a Windows-first workflow for local network automation study, so changes should keep the repo simple, safe, and easy to explain.

## Ground Rules

- Keep the host Windows-first.
- Keep Linux-only tooling in WSL2 Ubuntu or Docker.
- Keep all data synthetic.
- Do not add real credentials, proprietary images, or customer information.
- Document rollback notes for every mutating workflow.
- Prefer explicit validation over silent assumptions.

## Local Validation

From Windows PowerShell:

```powershell
pwsh -File .\scripts\Test-HostPrereqs.ps1
pwsh -File .\scripts\New-LabEnv.ps1
```

From WSL2 Ubuntu:

```bash
make validate
make test
```

PowerShell unit tests live in `tests/powershell/`.

Python tests live in `tests/python/`.

## Style Notes

- Prefer small, readable scripts over clever ones.
- Use structured logging for operational steps.
- Keep docs practical and easy to scan.
- Use hyphens, not long dashes, in prose.

## Pull Request Checklist

- The change still works from Windows first.
- The change does not blur the host and runtime boundary.
- The change is local-only and synthetic.
- The README or docs were updated if behavior changed.
- Rollback steps are clear.

