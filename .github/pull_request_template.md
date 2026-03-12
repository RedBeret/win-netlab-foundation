## Summary

Describe the change in a few clear sentences.

## Why This Change

- Explain the problem being solved
- Call out any host or runtime boundary impact

## Validation

- [ ] `pwsh -File .\scripts\Test-HostPrereqs.ps1`
- [ ] `pwsh -File .\scripts\New-LabEnv.ps1`
- [ ] `make validate`
- [ ] `make test`

## Safety Check

- [ ] No real credentials
- [ ] No real device identifiers
- [ ] No customer or proprietary data
- [ ] Rollback notes updated for mutating workflows

