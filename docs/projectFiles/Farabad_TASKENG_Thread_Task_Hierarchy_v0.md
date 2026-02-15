# Farabad TASKENG Thread/Task Hierarchy Spec (v0 Stub)

## Scope
Defines the v0 persistence and snapshot contract for thread-parented lead incident tasks.

## Thread record store
- mission key: `taskeng_v0_thread_store`
- type: `HASHMAP` keyed by `thread_id`
- record fields:
  - `thread_id` (STRING)
  - `type` (STRING)
  - `confidence` (NUMBER)
  - `heat` (NUMBER)
  - `parent_task_id` (STRING)

## Parent-case helper contract
- `ARC_fnc_taskengEnsureParentCaseTask(threadRec)` ensures a deterministic parent task exists before lead-generated incident creation.
- Parent task id convention: `CASE:<thread_id>`.
- Idempotency rules:
  - If `threadRec.parent_task_id` exists and is present in task store, return it.
  - Else if `CASE:<thread_id>` exists, return it.
  - Else create parent record once and persist linkage.

## Lead-driven generated task linkage
Lead-driven child tasks must persist:
- `task_type = "LEAD_CHILD"` (or future specific subtype)
- `parent_task_id`
- `thread_id`
- `thread_type`
- `thread_confidence`
- `thread_heat`
- `linkage` hashmap with same metadata

Snapshot `taskeng.rows` includes linkage display metadata:
`[task_id, state, accepting_unit_key, marker, updated_ts, followon_token, parent_task_id, thread_id, task_type]`

## Rehydrate/restart behavior
- `taskeng_v0_thread_store` is persisted and migrated via schema rev 4.
- helper must remain idempotent if called repeatedly after load/rehydrate.

## QA register addition
Add a dedicated QA case:
- **lead incident appears under correct parent case task**
- Assert child row includes expected `parent_task_id` linkage and parent task exists.
