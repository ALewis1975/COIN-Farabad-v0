# Threat Validation Evidence Framework v1

## Scope

This Epic 6 slice implements the validation framework only: matrix/checklists/procedure/evidence structure for proving existing threat behavior.

- No new runtime threat features are introduced in this PR.
- Final validation closure is deferred until Local MP + dedicated + JIP + restart/reconnect evidence is recorded.

## Validation matrix scope

| Contract area | Source epic(s) | Local MP | Dedicated | JIP (late join) | Restart | Reconnect | In-flight lifecycle edge |
|---|---|---|---|---|---|---|---|
| API/event schema and payload integrity | Epic 1 | Required | Required | Required | Required | Optional | Required |
| IED lifecycle idempotency / cleanup closure | Epic 2 | Required | Required | Required | Required | Required | Required |
| TOC/S2 threat surfacing read models | Epic 3 | Required | Required | Required | Optional | Optional | Optional |
| Family normalization + denied-transition evidence | Epic 4 | Required | Required | Optional | Optional | Optional | Required |
| Persistence/migration/reset invariants | Epic 5 | Optional | Required | Required | Required | Required | Required |
| Economy observability contract | Epic 7 | Required | Required | Required | Optional | Optional | Required |
| Virtual OpFor observability contract | Epic 8 | Required | Required | Required | Required | Required | Required |

All rows in active validation passes must be logged in `tests/TEST-LOG.md` as `PASS`, `FAIL`, or `BLOCKED`.

## Evidence status semantics

- `PASS`: check was executed in the named environment and produced expected result with linked artifact(s).
- `FAIL`: check was executed and produced reproducible unexpected behavior; follow-up fix PR required.
- `BLOCKED`: check was not executable due to missing dependency or environment.

### Required fields for every BLOCKED row

Every `BLOCKED` entry must include:

1. owner (`Owner: <team/person>`)
2. blocked date (`Date: YYYY-MM-DD`)
3. required environment/dependency (`Requires: dedicated/JIP/restart rig`, etc.)
4. follow-up action (`Next step: ...`)

## Step-by-step procedures

### 1) Local MP smoke procedure

1. Start hosted/local MP session with threat systems enabled.
2. Exercise representative threat lifecycle path (create -> activate -> close/cleanup) and inspect read models.
3. Record observed state/event evidence in `tests/TEST-LOG.md`.
4. Mark row `PASS` only when expected outputs and log evidence match.

### 2) Dedicated server procedure

1. Start dedicated server mission with matching mod/config baseline.
2. Verify server-authoritative state publication and threat snapshots.
3. Execute threat lifecycle/economy/virtual-pool checks from the matrix.
4. Record artifacts (RPT excerpts, snapshot keys, observed timestamps) in `tests/TEST-LOG.md`.

### 3) JIP late-join procedure

1. Keep dedicated session active with in-flight threat activity.
2. Connect a fresh late-join client.
3. Verify JIP client sees consistent `ARC_pub_state.threat`, `threatEconomy`, and `threatVirtualPool` snapshots.
4. Record PASS/FAIL evidence with exact environment notes.

### 4) Restart/save-load procedure

1. Capture pre-restart snapshot references for threat/economy/virtual pool.
2. Perform save/load or controlled restart sequence.
3. Verify restored state integrity and lifecycle continuity.
4. Record deterministic match/mismatch evidence in `tests/TEST-LOG.md`.

### 5) Reconnect/respawn procedure

1. During active threat lifecycle flow, disconnect and reconnect test client (or respawn equivalent edge).
2. Verify ownership/read-model continuity and no duplicate lifecycle side effects.
3. Log evidence with PASS/FAIL/BLOCKED status.

### 6) In-flight lifecycle edge procedure

1. Trigger edge cases (duplicate spawn request, stale close, cleanup convergence, virtual materialize/despawn transitions).
2. Verify expected event/evidence emission and bounded-state behavior.
3. Record explicit artifacts tied to each edge row in the matrix.

## Acceptance mapping (Epics 1–5, 7, 8)

For each acceptance criterion consumed from Epics 1–5, 7, and 8:

- map to at least one matrix row,
- identify target environment(s),
- identify expected proof artifact (log line/snapshot field/procedure step),
- record current status (`PASS`/`FAIL`/`BLOCKED`) in `tests/TEST-LOG.md`.

## TEST-LOG evidence conventions for Epic 6

Each Epic 6 validation pass entry in `tests/TEST-LOG.md` must include:

- branch/commit reference,
- command/step performed,
- result (`PASS`, `FAIL`, `BLOCKED`),
- evidence notes.

If a row is `BLOCKED`, include `Owner`, `Date`, `Requires`, and `Next step`.

## Closure report template

Use this template when publishing Epic 6 closure status:

```markdown
## Threat Epic 6 Closure Report

- Scope: validation/evidence closure only
- Commit/Branch:
- Date:

| Contract row | Evidence artifact(s) | Status |
|---|---|---|
| ... | ... | PASS/FAIL/BLOCKED |

### Unresolved risks
- Risk ID:
- Description:
- Status:
- Owner:
- Environment dependency:
- Target resolution date:

### Claim guard
Final validation closure MUST NOT be claimed unless every required evidence row is PASS with linked artifacts.
```

## Unresolved-risk ledger format

Use this ledger format for any open validation risk:

| Risk ID | Contract row | Risk description | Current status | Owner | Date logged | Required environment | Planned follow-up |
|---|---|---|---|---|---|---|---|
| E6-RISK-001 | Example row | Example unresolved gap | BLOCKED | Threat QA owner | 2026-05-13 | Dedicated + JIP + restart rig | Schedule dedicated validation pass |
