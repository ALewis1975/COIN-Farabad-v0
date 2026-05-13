# Epic 2 — IED Suspicious-Object Lifecycle Audit and Explicit Execution Contract

## Scope
Audit and formalize the IED suspicious-object lifecycle contract:
create -> spawn path -> discovery/interaction -> neutralization -> cleanup -> closure evidence.

## Status framing
- **Implemented:** threat creation/update/incident-close hooks and cleanup labeling utilities.
- **Partially implemented:** explicit suspicious-object spawn contract and restart-safe rehydration evidence.
- **Validation-only:** dedicated/JIP/restart proof for lifecycle correctness.

## Deliverables
1. Lifecycle sequence spec (authoritative transitions + allowed state changes).
2. Spawn-path contract (who can spawn, when, and with what idempotency keys).
3. Cleanup/close contract aligning threat record, task linkage, and labels.
4. Failure-path matrix (spawn denied, neutralization race, stale incident close).

## PR-sized work packages (future implementation)
- **E2-WP1:** Build lifecycle state machine table and transition guards.
- **E2-WP2:** Implement/normalize explicit suspicious-object spawn path contract.
- **E2-WP3:** Harden cleanup synchronization between threat/task/incident records.
- **E2-WP4:** Add restart and duplicate-spawn regression checks.

## Dependencies
- Epic 1 event/schema contract should be available for transition telemetry.
- Feeds Epic 5 (persistence rules) and Epic 6 (validation closure).

## Acceptance criteria
- Lifecycle states and transitions are explicit and single-authority.
- Spawn path cannot duplicate active manifestations across restart/recovery.
- Cleanup semantics are deterministic and logged.
- Incident closure and threat closure behavior are consistent.

## Validation & evidence requirements
- Static: compat scan + sqflint on touched SQF.
- Local MP smoke: create, discover, neutralize, cleanup sequences.
- Dedicated/JIP/restart: no duplicate spawn, no orphaned threat state, late join consistency.

## Non-goals
- Threat-family expansion beyond suspicious-object IED path (Epic 4).
