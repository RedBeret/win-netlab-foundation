# ADR 002: Use PowerShell Wrappers and Idempotent Repo-Local Scaffolding

## Status

Accepted

## Context

The repo needs one-command entrypoints for Windows users, but it must not overwrite local state or silently install host software.

## Decision

Implement PowerShell wrapper scripts that validate prerequisites, create local config files only when missing, and record outcomes with structured logs.

## Consequences

- Re-running setup is safe.
- Generated files are easy to explain and remove.
- Users learn the platform without guessing where state lives.

