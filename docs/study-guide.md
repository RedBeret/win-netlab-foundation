# Study Guide

## PowerShell vs Bash Responsibilities

Use PowerShell on Windows for:

- Host prerequisite checks
- Orchestration from the Windows desktop
- File scaffolding in the repo
- Local artifact inspection
- Docker Desktop lifecycle control

Use Bash inside WSL for:

- `make` targets
- Python execution for Linux-style automation workflows
- pytest and future Linux-side automation tools
- Any command that assumes POSIX paths or Linux package layout

## Decision Rule

If the command needs `wsl.exe`, Bash quoting, `/mnt/c/...` paths, or a Linux package manager, it belongs in WSL.

If the command is about the Windows workstation state, Docker Desktop, or user-facing orchestration, it belongs in PowerShell.

## Path Translation Example

Windows path:

```text
C:\Users\1stev\Documents\codexworkspace\win-netlab-foundation
```

WSL path:

```text
/mnt/c/Users/1stev/Documents/codexworkspace/win-netlab-foundation
```

## Practice Loop

1. Run `pwsh -File .\scripts\Test-HostPrereqs.ps1`.
2. Fix one failed prerequisite.
3. Re-run the report and inspect `artifacts/host-health.json`.
4. Run `pwsh -File .\scripts\Invoke-Demo.ps1`.
5. Open `artifacts/lab-summary.json` and `artifacts/lab-state.db`.

## Questions to Ask Yourself

- Did I keep Linux-only tooling out of the Windows host?
- Did I use only synthetic identifiers and documentation IPs?
- Can I rerun the same command without manual cleanup?
- Do I know the rollback command before I start a mutating workflow?

