# Copilot Instructions for COIN-Farabad-v0 (SQF / Arma 3)

## 1) Runtime context and authority model
- Language/runtime: SQF on Real Virtuality 4 (Arma 3 mission environment).
- Treat the **dedicated server as the single authority** for persistent/shared mission state.
- Clients are read-only for authoritative state: clients may request actions, never finalize global state.
- Apply state changes only on server-side execution paths (`isServer`/server-owned handlers), then replicate to clients.
- Keep ownership explicit: document where each variable is written, and avoid multi-writer logic.

## 2) Required local validation before merge
Run this minimum flow locally before merging:
- **Compile audit**
  - Verify mission scripts compile without SQF syntax/runtime load errors.
  - Check RPT/log output for undefined variables, missing functions, and script errors.
- **Local multiplayer checks**
  - Host local MP session (dedicated-like or hosted) with at least one client.
  - Exercise changed gameplay paths and networked interactions.
  - Confirm state replication and no authority violations (server writes, clients consume).

## 3) Deferred checks (must run in dedicated server + JIP environment)
These are not complete in basic local runs and must be validated separately:
- Dedicated server persistence/ownership behavior over longer sessions.
- Join-in-progress (JIP) synchronization for all changed state/UI.
- Late-client recovery for in-flight events and mission variables.
- Respawn/reconnect edge cases where state reinitialization can diverge.

## 4) Required test-log update
- After each validation pass, append/update the repo test log at:
  - `tests/TEST-LOG.md`
- Include:
  - Date/time, branch/commit, scenario, commands/steps, observed result.
  - Status label per check:
    - `PASS` (validated and clean)
    - `FAIL` (reproducible issue)
    - `BLOCKED` (environment unavailable, e.g., no dedicated/JIP rig)

## 5) Red-flag patterns to avoid
- Client-side mutation of authoritative mission state (`missionNamespace`/global vars) without server mediation.
- Remote execution paths that allow clients to self-authorize privileged actions.
- Multiple writers for the same replicated variable without explicit arbitration.
- UI/event handlers directly applying global state changes instead of server requests.
- Silent failure patterns (missing log/assert on authority or replication mismatch).
