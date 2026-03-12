# Security Policy

## Scope

This repository is for local-only synthetic training workflows.

It must not contain:

- real credentials
- customer data
- proprietary images
- live device inventory
- production IP addresses

## Reporting

If you find a security issue in the code or repo contents, open a private report through GitHub security reporting if enabled for the repository. If that is not available, contact the maintainer directly instead of opening a public issue with sensitive details.

## Safe Contributions

Before opening a pull request, confirm that:

- all identifiers are synthetic
- all IP addresses stay inside RFC5737 documentation space
- all rollback steps are documented for mutating workflows
- no change encourages Linux-only tools to run directly on the Windows host

