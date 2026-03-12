# ADR 001: Use Windows as the Host and WSL2 Ubuntu as the Linux Runtime

## Status

Accepted

## Context

The training series targets a Windows workstation but needs Linux-native tooling for later labs.

## Decision

Use Windows PowerShell as the primary operator interface and WSL2 Ubuntu as the default Linux runtime.

## Consequences

- Windows users get a predictable entrypoint.
- Linux-only commands stay isolated in a Linux environment.
- Later labs can reuse the same shell boundary instead of redefining it.

