# SITREP Gate Parity Specification

## Purpose
This document defines parity expectations between:
1. **Client pre-checks** (UX guardrails before submit), and
2. **Server authority checks** (authoritative allow/deny gate).

The goal is deterministic behavior: the client should predict likely outcomes, but the server remains the only source of truth.

---

## 1) Allowed/Blocked Conditions by Incident Type and State

### Canonical task states
- `OFFERED`
- `ACCEPTED`
- `IN_PROGRESS`
- `COMPLETE_PENDING_SITREP`
- `SITREP_SUBMITTED_PENDING_TOC`
- `FOLLOWON_ORDERED_PENDING_UNIT_ACK`
- `CLOSED`

### Canonical incident types
- `UNIT_ACCEPT`
- `UNIT_NOTE`
- `UNIT_PROGRESS`
- `UNIT_COMPLETE`
- `UNIT_SITREP_SUBMIT`
- `TOC_DECISION`
- `UNIT_FOLLOWON_ACK`
- `UNIT_FOLLOWON_UNABLE`

### Gate matrix

| Incident Type | Allowed States | Blocked States | Additional Conditions | Result on Allow |
|---|---|---|---|---|
| `UNIT_ACCEPT` | `OFFERED` | all others | caller has `SCOPE_TASK_ACCEPT` and is in authorized accepting role | state -> `ACCEPTED` |
| `UNIT_NOTE` | `ACCEPTED`, `IN_PROGRESS`, `COMPLETE_PENDING_SITREP`, `SITREP_SUBMITTED_PENDING_TOC`, `FOLLOWON_ORDERED_PENDING_UNIT_ACK` | `OFFERED`, `CLOSED` | non-empty note text; if current state is `FOLLOWON_ORDERED_PENDING_UNIT_ACK` and reason category is `UNABLE`, reason is mandatory | `ACCEPTED` -> `IN_PROGRESS`; otherwise keep current state unless special UNABLE route transitions per rule below |
| `UNIT_PROGRESS` | `ACCEPTED`, `IN_PROGRESS` | all others | caller has unit-write authority | `ACCEPTED` -> `IN_PROGRESS`; `IN_PROGRESS` idempotent |
| `UNIT_COMPLETE` | `ACCEPTED`, `IN_PROGRESS` | all others | caller has unit-write authority | state -> `COMPLETE_PENDING_SITREP` |
| `UNIT_SITREP_SUBMIT` | `COMPLETE_PENDING_SITREP` | all others | valid SITREP payload, required fields present, caller has SITREP authority | state -> `SITREP_SUBMITTED_PENDING_TOC` when TOC gate enabled; else `CLOSED` |
| `TOC_DECISION` (`RTB`/`HOLD`/`PROCEED`) | `SITREP_SUBMITTED_PENDING_TOC` | all others | caller has TOC authority; decision enum valid | state -> `FOLLOWON_ORDERED_PENDING_UNIT_ACK` |
| `UNIT_FOLLOWON_ACK` | `FOLLOWON_ORDERED_PENDING_UNIT_ACK` | all others | follow-on token must match active token; caller has unit authority | state -> `CLOSED` |
| `UNIT_FOLLOWON_UNABLE` | `FOLLOWON_ORDERED_PENDING_UNIT_ACK` | all others | non-empty reason required; follow-on token must match active token | state -> `SITREP_SUBMITTED_PENDING_TOC` |

### Incident-type-specific blocked examples

- `UNIT_SITREP_SUBMIT` while task is `IN_PROGRESS` -> blocked (`E_STATE_NOT_READY_FOR_SITREP`).
- `TOC_DECISION` before SITREP submission -> blocked (`E_STATE_NOT_PENDING_TOC`).
- `UNIT_FOLLOWON_ACK` with stale token -> blocked (`E_TOKEN_MISMATCH`).
- `UNIT_FOLLOWON_UNABLE` with blank reason -> blocked (`E_REASON_REQUIRED`).

---

## 2) Required Parity: Client Pre-check vs Server Authority Check

### Principle
- Client pre-checks **must mirror** the server rules for user feedback.
- Server checks are **authoritative** and can never be bypassed by client state.
- Any rule added server-side must be reflected in client pre-checks in the same release.

### Parity requirements

1. **Shared rule vocabulary**
   - Both layers use the same incident types, task states, and decision enums.
   - If new enum/state is introduced, both client and server contracts are updated.

2. **Shared reason-code outcomes**
   - For every denied rule, client and server emit the same canonical `reasonCode` where possible.
   - If client cannot evaluate a condition locally (e.g., stale token race), use `E_SERVER_AUTHORITY_REQUIRED` as pre-check fallback and defer to server.

3. **Evaluation order parity**
   - Evaluate in this order to avoid drift:
     1) malformed payload / missing required fields,
     2) authority/role,
     3) state gate,
     4) token/idempotency checks,
     5) subsystem-specific constraints.

4. **Idempotency parity**
   - Known re-entry paths (e.g., progress in `IN_PROGRESS`, repeat submit in already submitted path) should map to explicit idempotent codes and non-fatal UX handling.

5. **Race handling parity**
   - Client displays optimistic validation only.
   - Final UX message is reconciled to server response; if conflict occurs, server reason code supersedes client prediction.

6. **Telemetry parity**
   - Both layers include equivalent breadcrumbs for deny/allow outcomes using the payload shape below.

---

## 3) Diagnostic Reason-Code Dictionary

### Success / informational
- `OK_ALLOWED` - incident accepted and applied.
- `OK_IDEMPOTENT` - incident accepted as no-op or duplicate-safe.

### Client/server validation failures
- `E_PAYLOAD_MALFORMED` - payload schema/shape invalid.
- `E_REQUIRED_FIELD_MISSING` - required field missing.
- `E_INVALID_ENUM` - enum value outside allowed set.

### Authority and role failures
- `E_AUTH_SCOPE_DENIED` - missing permission scope.
- `E_ROLE_NOT_AUTHORIZED` - caller role not in allowed role set.

### State-gate failures
- `E_STATE_NOT_ALLOWED` - generic state mismatch.
- `E_STATE_NOT_READY_FOR_SITREP` - submit attempted before `COMPLETE_PENDING_SITREP`.
- `E_STATE_NOT_PENDING_TOC` - TOC decision attempted outside `SITREP_SUBMITTED_PENDING_TOC`.
- `E_STATE_NOT_FOLLOWON_PENDING` - follow-on action attempted outside `FOLLOWON_ORDERED_PENDING_UNIT_ACK`.

### Follow-on/token failures
- `E_TOKEN_REQUIRED` - token missing where mandatory.
- `E_TOKEN_MISMATCH` - token does not match active server token.
- `E_TOKEN_EXPIRED_OR_STALE` - token is old due to newer server transition.

### Input-quality failures
- `E_REASON_REQUIRED` - reason/comment required and absent.
- `E_TEXT_TOO_LONG` - free text exceeds cap.

### System/race failures
- `E_CONFLICT_RETRY` - optimistic race conflict; caller should refresh/retry.
- `E_SERVER_AUTHORITY_REQUIRED` - client cannot fully evaluate; defer to server check.
- `E_INTERNAL_GUARD_FAILURE` - unexpected gate processing failure.

---

## 4) Expected Breadcrumb Payload Shape

Breadcrumb events should be emitted at both pre-check and authority-check stages.

### Event name
- `SITREP_GATE_EVAL`

### Required payload shape (JSON)

```json
{
  "event": "SITREP_GATE_EVAL",
  "stage": "client_precheck | server_authority",
  "outcome": "allow | deny | idempotent",
  "reasonCode": "OK_ALLOWED",
  "incidentType": "UNIT_SITREP_SUBMIT",
  "taskId": "TASK:12345",
  "taskStateBefore": "COMPLETE_PENDING_SITREP",
  "taskStateAfter": "SITREP_SUBMITTED_PENDING_TOC",
  "actor": {
    "unitKey": "A-1-PLT",
    "role": "PL",
    "playerId": "7656119..."
  },
  "authority": {
    "scope": "SCOPE_TASK_UNIT_WRITE",
    "tocGateEnabled": true
  },
  "decision": {
    "value": null,
    "followonTokenProvided": null,
    "followonTokenMatched": null
  },
  "validation": {
    "requiredFieldsPresent": true,
    "enumValid": true,
    "schemaVersion": "v1"
  },
  "timing": {
    "clientTs": "2026-01-27T12:34:56.789Z",
    "serverTs": "2026-01-27T12:34:56.950Z",
    "latencyMs": 161
  },
  "trace": {
    "requestId": "req-uuid",
    "sessionId": "session-uuid",
    "build": "console-1.4.0"
  }
}
```

### Field requirements
- `stage`, `outcome`, `reasonCode`, `incidentType`, `taskId`, `taskStateBefore`, and `trace.requestId` are mandatory.
- `taskStateAfter` is mandatory on `allow` and `idempotent`; optional on `deny`.
- `decision.followonToken*` fields are mandatory for follow-on actions.
- `timing.serverTs` is required on server events; optional on client events.

### Correlation expectations
- Client and server events for the same user action must share `trace.requestId`.
- Dashboards should aggregate by `(incidentType, outcome, reasonCode)` and track client/server mismatch rate.

---

## 5) Parity Acceptance Checklist

A parity implementation is considered complete only when all are true:
- Every gate rule in server authority logic has a corresponding client pre-check rule or explicit `E_SERVER_AUTHORITY_REQUIRED` fallback.
- Every deny path maps to a canonical reason code in this dictionary.
- Breadcrumb payload conforms to the required shape for both stages.
- Mismatch telemetry is visible and bounded (target: <1% predicted-allow but server-deny over rolling window).
