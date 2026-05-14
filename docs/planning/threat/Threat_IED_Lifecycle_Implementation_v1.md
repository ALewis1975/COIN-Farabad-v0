# Threat IED Lifecycle Implementation — Epic 2

## Status

**Epic 2 — IED Suspicious-Object Lifecycle Audit and Explicit Execution Contract**

Implementation completion for Epic 2 runtime gaps deferred from PR #506.

| Area | Status |
|---|---|
| Lifecycle transition guards | Implemented (PR #506) |
| Spawn idempotency token/key | Implemented (this PR) |
| Duplicate spawn prevention | Implemented (this PR) |
| Spawn linkage metadata (restart-safe) | Implemented (this PR) |
| Cleanup sync convergence | Implemented (this PR) |
| Stale close detection / CLOSED_STALE evidence | Implemented (this PR) |
| Active IED threat linkage | Implemented (current PR) |
| EOD RTB/TOW disposition lifecycle request | Implemented (current PR) |
| Driven VBIED / suicide objective production | Implemented (current PR) |
| Complex/chain IED status | Deferred — modules are registered but intentionally unreachable without future runtime-validation PR |
| Static contract checks | Implemented (this PR) |
| Local MP runtime smoke | BLOCKED — Arma 3 runtime unavailable in sandbox |
| Dedicated / JIP / restart validation | BLOCKED — requires dedicated server environment |

---

## 1. Lifecycle sequence (runtime mapping)

The runtime state vocabulary (`CREATED`, `ACTIVE`, `STAGED`, `DISCOVERED`, `NEUTRALIZED`,
`DETONATED`, `INTERDICTED`, `CLOSED`, `CLEANED`, `EXPIRED`) maps to the Epic 2 planning contract
states as follows:

| Planning contract state | Runtime state | Metadata field(s) |
|---|---|---|
| `LEAD_INGESTED` | `CREATED` | threat record created |
| `SPAWN_ELIGIBLE` / `SPAWN_REQUESTED` | `CREATED` | `world.spawn_token`, `world.spawn_intent_ts`, `world.spawn_attempt_count` |
| `SPAWNED_ACTIVE` | `ACTIVE` / `STAGED` | `world.spawned=true`, `world.spawned_at`, `world.objects_net_ids` |
| `DISCOVERED` | `DISCOVERED` | `state_ts.discovered` |
| `NEUTRALIZED` | `NEUTRALIZED` / `INTERDICTED` / `DETONATED` | `state_ts.neutralized` |
| `CLEANUP_PENDING` | `CLOSED` | `outcome.result`, `outcome.notes` |
| `SPAWN_DENIED` | `CREATED` (kept open) | `THREAT_SPAWN_DENIED` event emitted |
| `CLOSED_STALE` | `CLEANED` (unchanged) | `THREAT_CLOSED_STALE` event emitted |
| `CLOSED_COMPLETE` | `CLEANED` | `world.cleanup_completed=true`, `world.cleanup_ts` |

---

## 2. Spawn idempotency token/key contract

### Token format

```
SPTOKEN:<threat_id>:<floor(state_ts.created)>
```

The token is deterministic: it is derived from the stable threat identity (`threat_id`) and the
integer-floored creation epoch (`state_ts.created`). The same token is produced on every call
for the same threat, so a retry after a partial write cannot produce a new distinct token.

### Token lifecycle

1. On first spawn request: token is computed, written to `world.spawn_token`, and `spawn_intent_ts`
   + `spawn_attempt_count` are set.
2. On duplicate spawn request while `world.spawned = true`: request is denied with
   `DENY_DUPLICATE_SPAWN`; `THREAT_SPAWN_DENIED` event is emitted; no state mutation occurs.
3. On retry spawn request while `world.spawned = false`: allowed (previous spawn intent was not
   completed); token is overwritten with the same deterministic value; attempt count increments.

### Restart-safe rehydration readiness

The following fields written during spawn intent are stable for Epic 5 persistence/rehydration:

| Field | Location | Content |
|---|---|---|
| `spawn_token` | `world` sub-record | Deterministic token string |
| `spawn_intent_ts` | `world` sub-record | `serverTime` of intent write |
| `spawn_attempt_count` | `world` sub-record | Integer; increments on each grant |
| `spawned` | `world` sub-record | `true` once object is linked |
| `spawned_at` | `world` sub-record | `serverTime` when object was linked |
| `objects_net_ids` | `world` sub-record | Array of linked object net IDs |
| `cleanup_label` | `world` sub-record | `"THREAT:IED:<threat_id>"` |

Epic 5 persistence work can serialize and restore these fields to prevent duplicate spawning
across mission restarts.

---

## 3. Cleanup/close convergence contract

### `ARC_fnc_threatIedCleanupSync` — server-only

Provides deterministic idempotent cleanup convergence for IED threat records.

**Input:** `[threat_id, source_label]`

**Behavior:**
- If threat is already `CLEANED` or `world.cleanup_completed = true`: emits
  `THREAT_CLEANUP_STALE` evidence event and returns `true` without mutating state.
- Otherwise:
  1. Ensures `world.cleanup_label` is canonical (`THREAT:IED:<threat_id>`).
  2. Writes `world.cleanup_completed = true`, `world.cleanup_ts`, `world.cleanup_source`.
  3. Calls `ARC_fnc_threatUpdateState` to drive the `CLEANED` transition (guarded/idempotent).

### Cleanup evidence fields

| Field | Location | Content |
|---|---|---|
| `cleanup_completed` | `world` | `true` once convergent cleanup applied |
| `cleanup_ts` | `world` | Timestamp of cleanup application |
| `cleanup_source` | `world` | Source label (e.g. `INCIDENT_CLOSED`, `TIMEOUT`) |

---

## 4. Failure-path handling

### Spawn denied

- **Trigger:** `ARC_fnc_threatIedSpawnRequest` called while `world.spawned = true`.
- **Handling:** `DENY_DUPLICATE_SPAWN` deny reason; `THREAT_SPAWN_DENIED` structured event emitted;
  no mutation to threat record.
- **Operator visibility:** event appears in `threat_v0_events_public` and OPS log.

### Neutralization race

- **Trigger:** Multiple players/paths attempt `DISCOVERED → NEUTRALIZED` simultaneously.
- **Handling:** `ARC_fnc_threatUpdateState` guards transitions; first valid server transition wins;
  subsequent calls get `DENY_STATE_NOOP` or `DENY_TRANSITION_INVALID` and log it.
- **Operator visibility:** `THREAT_STATE_CHANGE_DENIED` events emitted for denied races.

### Stale incident close (late close after CLEANED)

- **Trigger:** `ARC_fnc_threatOnIncidentClosed` called for a threat already in `CLEANED` state.
- **Handling:** `THREAT_CLOSED_STALE` structured event emitted via `ARC_fnc_threatEmitEvent`;
  no state mutation; terminal state is preserved unchanged.
- **Operator visibility:** stale event recorded in event log for operator diagnosis.

### Duplicate spawn retry

- **Trigger:** AO activation hook called twice (e.g. system replay, mission restart mid-incident).
- **Handling:** Second call hits `DENY_DUPLICATE_SPAWN` guard; `THREAT_SPAWN_DENIED` event emitted.
- **Operator visibility:** duplicate attempt count and denial reason in OPS log.

---

## 5. Function registry

| Function | File | Authority |
|---|---|---|
| `ARC_fnc_threatIedSpawnRequest` | `functions/threat/fn_threatIedSpawnRequest.sqf` | Server-only |
| `ARC_fnc_threatIedCleanupSync` | `functions/threat/fn_threatIedCleanupSync.sqf` | Server-only |
| `ARC_fnc_threatOnAOActivated` | `functions/threat/fn_threatOnAOActivated.sqf` | Server-only |
| `ARC_fnc_threatOnIncidentClosed` | `functions/threat/fn_threatOnIncidentClosed.sqf` | Server-only |

---

## 6. Static validation

Run: `bash tests/static/threat_ied_lifecycle_contract_checks.sh`

Checks cover:
- Spawn idempotency token derivation and metadata fields
- Duplicate spawn denial and event emission
- Object spawn-token tagging
- Active IED threat linkage and detonation-to-`DETONATED` lifecycle updates
- EOD RTB/TOW disposition RPC registration, sender validation, and lifecycle flags
- Driven VBIED and suicide bomber objective-kind production gates
- Explicit deferred status for complex/chain IED modules
- Cleanup convergence markers
- Stale close detection and evidence emission
- CfgFunctions registration

---

## 7. Remaining runtime validation (BLOCKED)

These checks require the Arma 3 dedicated server environment and cannot be validated in the
CI/static sandbox:

| Check | Status | Required environment |
|---|---|---|
| Spawn idempotency survives AO re-trigger | BLOCKED | Local MP / Dedicated |
| Duplicate spawn denied across restart | BLOCKED | Dedicated + mission restart |
| Stale incident close evidence appears in RPT | BLOCKED | Local MP / Dedicated |
| Cleanup sync convergence in JIP session | BLOCKED | Dedicated + JIP |
| Cleanup_completed field persists across reconnect | BLOCKED | Dedicated + reconnect |
| RTB_IED approval, collection, transport, and delivery | BLOCKED | Local MP / Dedicated |
| TOW_VBIED safe tow, at-site destruction, and disposal credit | BLOCKED | Local MP / Dedicated |
| Driven VBIED objective production and spawn tick staging | BLOCKED | Dedicated + player near spawn path |
| Suicide bomber CRITICAL-tier objective production and spawn denial below CRITICAL | BLOCKED | Dedicated + district posture setup |
| activeIedThreatId clears on new package and rehydrates correctly for JIP readers | BLOCKED | Dedicated + JIP/reconnect |

Owner follow-up: validate above in dedicated environment before Epic 5 persistence/migration work
relies on these fields.
