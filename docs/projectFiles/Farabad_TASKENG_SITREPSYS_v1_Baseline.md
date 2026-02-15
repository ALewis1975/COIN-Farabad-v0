# Farabad TASKENG + SITREPSYS v1 Baseline (Single Source of Truth)

This document is the authoritative contract for the current TASKENG/SITREPSYS loop on `v00`.

Use this as the baseline for implementation, QA, and documentation updates.

---

## 1) Canonical task states and allowed transitions

### Canonical TASKENG states

- `OFFERED`
- `ACCEPTED`
- `IN_PROGRESS`
- `COMPLETE_PENDING_SITREP`
- `SITREP_SUBMITTED_PENDING_TOC`
- `FOLLOWON_ORDERED_PENDING_UNIT_ACK`
- `CLOSED`

### Allowed transitions (only)

| From | Trigger | To | Notes |
|---|---|---|---|
| `OFFERED` | Unit `ACCEPT` | `ACCEPTED` | Acceptance is role/authority gated. |
| `ACCEPTED` | Unit `PROGRESS` | `IN_PROGRESS` | First progress marks active execution. |
| `ACCEPTED` | Unit `NOTE` | `IN_PROGRESS` | First note also promotes to in-progress. |
| `ACCEPTED` / `IN_PROGRESS` | Unit `COMPLETE` | `COMPLETE_PENDING_SITREP` | Creates pending SITREP record before state commit. |
| `COMPLETE_PENDING_SITREP` | Unit `SITREP_SUBMIT` | `SITREP_SUBMITTED_PENDING_TOC` or `CLOSED` | `taskeng_v0_toc_gate_enabled=true` routes to TOC gate; otherwise closes directly. |
| `SITREP_SUBMITTED_PENDING_TOC` | TOC decision (`RTB`/`HOLD`/`PROCEED`) | `FOLLOWON_ORDERED_PENDING_UNIT_ACK` | Decision is recorded but does **not** close task. |
| `FOLLOWON_ORDERED_PENDING_UNIT_ACK` | Unit `FOLLOWON_ACK` | `CLOSED` | Unit ACK is the close condition for follow-on path. |
| `FOLLOWON_ORDERED_PENDING_UNIT_ACK` | Unit `NOTE` with reason (UNABLE path) | `SITREP_SUBMITTED_PENDING_TOC` | UNABLE returns task to TOC queue for a new decision. |

### Explicit follow-on/UNABLE behavior

- `FOLLOWON_ORDERED_PENDING_UNIT_ACK` is mandatory once TOC orders `RTB/HOLD/PROCEED`; the task remains open until unit ACK or UNABLE.
- UNABLE is encoded as a unit `NOTE` while in follow-on-pending state; a non-empty reason is required.
- UNABLE must return the task to `SITREP_SUBMITTED_PENDING_TOC` so TOC can re-issue follow-on.

---

## 2) Required authority scope per transition

### Scope contracts

- **Task issue** (`CREATE`): `SCOPE_TASK_ISSUE`
  - Resolved via `ARC_fnc_cmdAuth_resolve`.
  - Unit-level authority does not grant this scope; intended for HQ/BN bypass workflows.
- **Task accept** (`ACCEPT`): `SCOPE_TASK_ACCEPT`
  - Enforced through `ARC_fnc_taskengAuthAccept` → `ARC_fnc_cmdAuth_resolve`.
- **Task unit writes** (`NOTE`, `PROGRESS`, `COMPLETE`, `SITREP_SUBMIT`, `FOLLOWON_ACK`, UNABLE-return NOTE): `SCOPE_TASK_UNIT_WRITE`
  - Enforced through `ARC_fnc_taskengAuthUnitWrite` → `ARC_fnc_cmdAuth_resolve`.

### TOC decision permissions (non-unit-ownership path)

TOC follow-on decisions are HQ actions and are intentionally not restricted to owning unit membership.

A TOC decision is permitted if **any** of the below is true:

1. `admin > 0`, or
2. actor matches BN bypass var set (`cmdauth_v0_bn_bypass_vars`, default `tf_co/tf_xo/tf_csm`), or
3. actor role description matches TOC keyword list (battle captain/NCO, operations/S3, COS, commander/XO/1SG/PL/PSG/SL).

---

## 3) SITREP payload contract

### Submission preconditions

- Task must be in `COMPLETE_PENDING_SITREP`.
- Narrative is required and trimmed; empty narrative is denied.
- Narrative max length: **800 chars**.

### Request payload shape (unit update)

- Request op: `['TASKENG','UNIT_UPDATE']`
- Payload:
  - `[0]` action string (`'SITREP_SUBMIT'`)
  - `[1]` narrative string (required)
  - `[2]` optional structured fields (`HASHMAP` or array-of-pairs)

### Structured field contract (`fields`)

Supported normalized keys:

- `rec_coa`: `RTB | HOLD | PRCD` (normalized uppercase; other values become empty)
- `rec_rtb_reasons`: array of strings (uppercased)
- `req_support`: array of strings (uppercased)
- `other_text`: string, max 120
- `lace`: 4-element string array `[L, A, C, E]`, each max 30

Server stores both:

- canonical normalized fields (`rec_coa`, `rec_rtb_reasons`, `req_support`, `other_text`, `lace`), and
- original `fields` map for compatibility/UI evolution.

---

## 4) Required server logs per transition

These logs are mandatory observability points for the loop and align with names already present in code and the dedicated MP test register.

### Core task lifecycle

- Issue/create:
  - `TASKENG_CREATE_ALLOW`
  - `TASKENG_TASK_CREATED`
  - `TASKENG_TASK_OFFERED`
- Accept:
  - `TASKENG_ACCEPT_ALLOW`
  - `TASKENG_TASK_ACCEPTED`
- Unit write transitions:
  - `TASKENG_UPDATE_ALLOW`
  - `TASKENG_TASK_TRANSITION`
  - `TASKENG_TASK_UPDATED` (non-terminal updates)
  - `TASKENG_TASK_COMPLETED` (`COMPLETE` path)

### SITREP path

- `SITREPSYS_PENDING_CREATED` (or `SITREPSYS_PENDING_EXISTS` idempotent path)
- `SITREPSYS_SUBMITTED`
- `TASKENG_TASK_SITREP_SUBMITTED` (TOC gate path)
- `TASKENG_TASK_CLOSED` (if SITREP closes directly with TOC gate disabled)

### TOC follow-on + ACK/UNABLE (P1.1 critical)

- `TASKENG_FOLLOWON_ORDERED` (`order=RTB/HOLD/PROCEED`)
- `TASKENG_FOLLOWON_ACKED` (`to=CLOSED`)
- `TASKENG_FOLLOWON_UNABLE` (`reason_len>0`)
- `TASKENG_TASK_CLOSED` (upon ACK close)

### Negative/guard visibility

- `TASKENG_*_DENY` and `TASKENG_TOC_DECISION_DENY` for auth/state/input failures.

---

## 5) Snapshot contract consumed by console

Console consumers must treat server snapshot data as authoritative and must not infer state client-side.

### Top-level CORE snapshot slots used

- `[8] sitrepsysSnap`
- `[10] taskengSnap`

### `taskengSnap` layout

`taskengSnap = [enabled, version, state, rev, openCount, closedCount, openRows, tocGateEnabled, tocRows, histRows]`

- `openRows[]`: `[task_id, state, accepting_unit_key, marker, updated_ts, followon_token, parent_task_id, thread_id, task_type]`
  - `followon_token` is populated when state is `FOLLOWON_ORDERED_PENDING_UNIT_ACK`.
  - linkage slots (`parent_task_id`, `thread_id`, `task_type`) are populated for lead-driven hierarchy flows and blank/default for standard tasks.
- `tocRows[]`: `[task_id, state, accepting_unit_key, marker, updated_ts]`
- `histRows[]`: bounded global history rows.

### `sitrepsysSnap` layout

`sitrepsysSnap = [enabled, version, state, rev, openCount, closedCount, openRows, sitrepMetaRows]`

- `openRows[]`: `[sitrepsys_id, task_id, state, reporting_unit_key, updated_ts]`
- `sitrepMetaRows[]` (TOC review metadata):
  - `[task_id, sitrep_id, reporting_unit_key, callsign, submitted_ts, submitted_world, rec_coa, rec_rtb_reasons, req_support, other_text, lace, narrative_len]`

### Console expectations

- Show follow-on pending ACK strictly from task state (`FOLLOWON_ORDERED_PENDING_UNIT_ACK`) and snapshot token.
- Show TOC queue strictly from `tocRows` / `sitrepMetaRows` (no synthetic queue logic).
- Treat ACK/UNABLE affordances as authority-gated server actions, not client-local state changes.

---

## 6) QA usage notes (test-register alignment)

For dedicated MP validation of this baseline, prioritize:

- DMP-033 (follow-on order requires unit ACK)
- DMP-034 (UNABLE returns to TOC queue)
- DMP-035 (JIP into follow-on pending ACK)

Expected log names in those tests must include:

- `TASKENG_FOLLOWON_ORDERED`
- `TASKENG_FOLLOWON_ACKED`
- `TASKENG_FOLLOWON_UNABLE`
- `TASKENG_TASK_CLOSED`

---


## 7) Sprint 1 execution scope guardrails

Execution plumbing is feature-flagged and defaults OFF to protect current v1 lifecycle behavior.

- Flag: `taskeng_v0_execution_enabled` (default `false`).
- Supported execution kinds for Sprint 1 only:
  - `HOLD`
  - `ARRIVE_HOLD`
  - `INTERACT`
  - `ROUTE_RECON`
  - `IED`
  - `VBIED`
- Execution data fields carried in task objective metadata:
  - `hold_seconds`
  - `arrive_seconds`
  - `arrive_radius_m`

### Interaction objective scope (Sprint 1)

- Only one interaction objective kind is in scope: `INTERACT` / `INTERACT_GENERIC`.
- Completion trigger is intentionally placeholder-only for now: `PLACEHOLDER_INTERACTION`.
- Unit action `INTERACT_COMPLETE` is only valid when execution flag is ON and objective execution kind is `INTERACT`.

### Explicitly disabled stubs (feature-flagged out)

The following objective families are treated as explicitly disabled stubs in Sprint 1 and must not activate their native execution behavior:

- `CONVOY`
- `IED_DEVICE`
- `VBIED_VEHICLE`

When one of these disabled kinds is requested, TASKENG records an explicit `kind_resolution` + `kind_resolution_reason` in the task execution metadata and falls back to a safe `HOLD` objective.

### Newly supported execution families (minimal server-authoritative criteria)

- `ROUTE_RECON`: `COMPLETE` is accepted only after at least one server-recorded unit note exists on the task (`EXEC_ROUTE_RECON_NOTE_OBSERVED`).
- `IED`: `COMPLETE` is server-authoritative and records `EXEC_IED_SERVER_CONFIRMED` as close-ready suggestion reason.
- `VBIED`: `COMPLETE` is server-authoritative and records `EXEC_VBIED_SERVER_CONFIRMED` as close-ready suggestion reason.

### Execution telemetry pathing

- `TASKENG_EXEC_KIND_PATH` emits requested/effective kind and resolution (`SUPPORTED`, `DISABLED_STUBBED`, `DISABLED_UNSUPPORTED`) at task creation.
- `TASKENG_EXEC_COMPLETE_PATH` emits per-kind completion criteria result at completion action handling.

### Close-ready suggestion path

When execution metadata is active, server records close-ready recommendation fields for review/audit:

- `close_ready_suggested_result`
- `close_ready_suggested_reason`

These fields are advisory only; TOC and existing SITREP/follow-on closure rules remain authoritative.

