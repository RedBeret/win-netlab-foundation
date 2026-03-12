# Review Questions

1. Why does this repo treat Windows as the control plane instead of running everything inside WSL?
2. Which tasks belong in PowerShell, and which tasks belong in WSL Bash?
3. Why are RFC5737 documentation ranges used for management IPs?
4. Why is `docker compose` optional for the platform but required for the one-command demo?
5. What makes `New-LabEnv.ps1` idempotent?
6. What files should you delete to roll back the demo state completely?
7. Why does the repo generate `artifacts/host-health.json` before starting the demo?
8. What is the value of storing demo state in SQLite instead of memory only?
9. How do structured logs help later labs stay debuggable?
10. What breaks if Linux-only tooling starts running directly on the Windows host?

