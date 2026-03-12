# ADR 003: Keep the Demo Fully Local and Synthetic

## Status

Accepted

## Context

The foundation repo should teach workflow and tooling, not expose users to risk from live devices, customer data, or proprietary images.

## Decision

Use synthetic hostnames, RFC5737 IP space, fake usernames, fake serials, a local Docker Compose health service, and SQLite for demo state.

## Consequences

- The demo stays safe to run on any workstation.
- Troubleshooting is focused on tooling and workflow rather than external systems.
- Later labs can add complexity without changing the safety baseline.

