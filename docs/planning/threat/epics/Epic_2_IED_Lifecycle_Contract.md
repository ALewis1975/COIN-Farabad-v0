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

## Lifecycle sequence spec (authoritative transitions)

This table defines the **target contract vocabulary** for Epic 2 planning. The first implementation slice enforces the current coarse runtime state vocabulary in `ARC_fnc_threatUpdateState` (`CREATED`, `ACTIVE`, `STAGED`, `DISCOVERED`, `NEUTRALIZED`, `DETONATED`, `INTERDICTED`, `CLOSED`, `CLEANED`, `EXPIRED`) while later E2 work packages normalize explicit spawn-path states such as `SPAWN_ELIGIBLE`, `SPAWN_REQUESTED`, and `CLEANUP_PENDING`.

Current runtime mapping for this PR:

Collapsed target states are distinguished today by existing record metadata (`links`, `world`, `outcome`, `audit`, and OPS/event notes), not by separate persisted runtime states: `SPAWN_ELIGIBLE`/`SPAWN_REQUESTED` collapse into `CREATED`, `SPAWNED_ACTIVE` collapses into `ACTIVE`/`STAGED`, and `SPAWN_DENIED`/`CLOSED_NO_SPAWN`/`CLOSED_STALE`/`CLOSED_COMPLETE` collapse into `EXPIRED`/`CLOSED`/`CLEANED`. Normalizing those collapsed states into explicit spawn-path fields remains E2-WP2 follow-up work.

| Target contract state | Current runtime state(s) enforced in this PR |
|---|---|
| `LEAD_INGESTED` | `CREATED` |
| `SPAWN_ELIGIBLE` / `SPAWN_REQUESTED` | `CREATED` (spawn contract metadata remains future E2-WP2 work) |
| `SPAWNED_ACTIVE` | `ACTIVE` / `STAGED` |
| `DISCOVERED` | `DISCOVERED` |
| `NEUTRALIZED` | `NEUTRALIZED` / `INTERDICTED` / `DETONATED` |
| `CLEANUP_PENDING` | `CLOSED` |
| `SPAWN_DENIED` / `CLOSED_NO_SPAWN` / `CLOSED_STALE` / `CLOSED_COMPLETE` | `EXPIRED` / `CLOSED` / `CLEANED` |

| State | Entry trigger | Server-authoritative transition(s) | Allowed state change | Notes |
|---|---|---|---|---|
| `LEAD_INGESTED` | Lead/task evidence reaches threat intake | `LEAD_INGESTED -> SPAWN_ELIGIBLE` or `LEAD_INGESTED -> CLOSED_NO_SPAWN` | Threat record create/update only | No client-side lifecycle writes. |
| `SPAWN_ELIGIBLE` | Eligibility checks pass (AO/time/limit gates) | `SPAWN_ELIGIBLE -> SPAWN_REQUESTED` or `SPAWN_ELIGIBLE -> SPAWN_DENIED` | Threat + incident pre-spawn metadata | Deny path must log reason code. |
| `SPAWN_REQUESTED` | Spawn request issued by server path | `SPAWN_REQUESTED -> SPAWNED_ACTIVE` or `SPAWN_REQUESTED -> SPAWN_DENIED` | Spawn-attempt metadata and idempotency token | Duplicate request resolves by token check. |
| `SPAWNED_ACTIVE` | Suspicious object manifestation exists | `SPAWNED_ACTIVE -> DISCOVERED` or `SPAWNED_ACTIVE -> CLEANUP_PENDING` | Manifest/object linkage and active flag | Client interactions are requests only. |
| `DISCOVERED` | Discovery/interaction evidence recorded | `DISCOVERED -> NEUTRALIZED` or `DISCOVERED -> CLEANUP_PENDING` | Interaction metadata and timestamps | Preserve actor and evidence references. |
| `NEUTRALIZED` | Neutralization succeeds | `NEUTRALIZED -> CLEANUP_PENDING` | Neutralization outcome and close intent | Race-safe close should remain idempotent. |
| `CLEANUP_PENDING` | Cleanup requested after neutralize/timeout | `CLEANUP_PENDING -> CLOSED_COMPLETE` or `CLEANUP_PENDING -> CLOSED_STALE` | Threat/task/incident cleanup markers | Single owner performs final cleanup write. |
| `SPAWN_DENIED` / `CLOSED_NO_SPAWN` / `CLOSED_STALE` / `CLOSED_COMPLETE` | Denial or closure path reached | Terminal unless explicitly reopened by server migration tool | Closure evidence + reason labels | Terminal states are append-only evidence updates. |

## Spawn-path contract

- **Who can spawn:** server-authoritative threat lifecycle path only; clients may request actions but cannot commit spawn state.
- **When spawn is allowed:** only from `SPAWN_ELIGIBLE` with required gates (valid threat record, AO eligibility, and no active manifestation already linked).
- **Idempotency key shape:** use a deterministic spawn token derived from stable threat identity + lifecycle epoch so retried requests map to a single manifestation intent.
- **Duplicate/retry behavior:** duplicate request with same token is a no-op update; conflicting token for an active threat is denied and logged as lifecycle drift risk.
- **Restart expectations (partial today):** restart-safe rehydration must restore token/manifest linkage before any new spawn request is accepted.

## Cleanup/close contract (threat/task/incident alignment)

- Cleanup writes are server-owned and applied once per lifecycle token.
- Threat closure state, linked task closure intent, and incident-close labels must converge in one deterministic close path.
- Cleanup completion requires evidence fields for: close reason, actor/source, timestamp, and manifestation disposition.
- Labeling utilities are treated as supporting metadata and cannot represent closure without aligned threat/task/incident terminal state.
- Stale or late close attempts after terminal closure are recorded as evidence-only updates (`CLOSED_STALE`) and must not reopen active lifecycle.

## Failure-path matrix

| Failure condition | Expected handling contract | Evidence gate |
|---|---|---|
| Spawn denied (`SPAWN_ELIGIBLE -> SPAWN_DENIED`) | Keep threat record open for future eligibility or close-no-spawn based on policy; emit deny reason and authority context. | Dedicated + restart run shows no duplicate manifestation after retry. |
| Neutralization race (multiple close/neutralize actions) | First valid server transition wins; subsequent actions become idempotent no-op/evidence-only updates. | Local MP + dedicated run shows single terminal state and stable task/incident linkage. |
| Stale incident close (late close after cleanup) | Record stale close attempt as non-authoritative evidence (`CLOSED_STALE`) without mutating closed lifecycle outcome. | JIP/restart evidence confirms late join reads unchanged terminal state. |

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
- Failure-path handling is defined for spawn denied, neutralization race, and stale incident close.

## Validation & evidence requirements
- Static: compat scan + sqflint on touched SQF.
- Local MP smoke: create, discover, neutralize, cleanup sequences.
- Dedicated/JIP/restart: no duplicate spawn, no orphaned threat state, late join consistency.
- Closure gate rule: no runtime lifecycle completion claim without dedicated/JIP/restart evidence artifacts.

## Non-goals
- Threat-family expansion beyond suspicious-object IED path (Epic 4).
