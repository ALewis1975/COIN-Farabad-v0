# TASKENG/SITREPSYS v00 State-Transition Matrix (v0 behavior parity reference)

Behavior source-of-truth reference: `docs/previousBuilds/v0/functions/core` (accept/progress/complete/sitrep/follow-on/closeout semantics).

## TASKENG transition matrix

| Operation | Allowed from | To | Idempotent re-entry |
|---|---|---|---|
| ACCEPT | OFFERED | ACCEPTED | ACCEPT by same unit when already ACCEPTED/IN_PROGRESS/terminal returns `IDEMPOTENT` |
| UNIT_UPDATE NOTE | ACCEPTED, IN_PROGRESS, COMPLETE_PENDING_SITREP, SITREP_SUBMITTED_PENDING_TOC, FOLLOWON_ORDERED_PENDING_UNIT_ACK | IN_PROGRESS (if ACCEPTED) else unchanged; FOLLOWON pending note routes UNABLE path | NOTE with no state change is valid no-op |
| UNIT_UPDATE PROGRESS | ACCEPTED, IN_PROGRESS | IN_PROGRESS | PROGRESS while IN_PROGRESS with empty note returns `IDEMPOTENT` |
| UNIT_UPDATE COMPLETE | ACCEPTED, IN_PROGRESS | COMPLETE_PENDING_SITREP | COMPLETE in COMPLETE_PENDING_SITREP or terminal states returns `IDEMPOTENT` |
| UNIT_UPDATE SITREP_SUBMIT | COMPLETE_PENDING_SITREP | SITREP_SUBMITTED_PENDING_TOC (TOC gate) or CLOSED (no gate) | Re-submit in SITREP_SUBMITTED_PENDING_TOC/CLOSED returns `IDEMPOTENT` |
| TOC_DECISION (RTB/HOLD/PROCEED) | SITREP_SUBMITTED_PENDING_TOC | FOLLOWON_ORDERED_PENDING_UNIT_ACK | Re-entry with same decision in follow-on pending/closed returns `IDEMPOTENT`; conflicting decision denied |
| UNIT_UPDATE FOLLOWON_ACK | FOLLOWON_ORDERED_PENDING_UNIT_ACK | CLOSED | Re-entry in CLOSED returns `IDEMPOTENT` |
| UNIT_UPDATE FOLLOWON_UNABLE | FOLLOWON_ORDERED_PENDING_UNIT_ACK | SITREP_SUBMITTED_PENDING_TOC | Requires reason; returns to TOC pending |

## SITREPSYS transition matrix

| Operation | Allowed from | To | Idempotent re-entry |
|---|---|---|---|
| Create pending | task complete path | OPEN | Existing OPEN record treated as idempotent-create |
| Submit pending | OPEN | SUBMITTED | SUBMITTED/CLOSED submit re-entry returns `IDEMPOTENT`; all other states denied |

## Restart persistence + dedupe invariants

- CORE remains the only persistence writer (reserved subsystem blobs).
- TASKENG/SITREPSYS own schema encode/decode helpers for blob payloads.
- Hydrate path always runs index reconciliation (`taskengReconcileIndexes`, `sitrepsysReconcileIndexes`) to dedupe duplicate index entries and restore canonical membership from authoritative records.
- Idempotent handlers intentionally tolerate network retries and server restart replay of late client RPCs.
