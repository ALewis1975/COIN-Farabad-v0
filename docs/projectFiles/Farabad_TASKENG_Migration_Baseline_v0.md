# Farabad TASKENG Persistence Migration Baseline (v0)

This document defines migration expectations for `taskeng_v0_*` persisted data.

## Current schema revision

- `taskeng_v0_schema_rev = 4`

Increment this value for every structural persistence change and add a migration step.

## Versioned migration table

### Revision 1
- Key: `taskeng_v0_active_incident_refs`
- Default: `[]`
- Decode fallback: if missing or wrong type, coerce to empty array.

### Revision 2
- Key: `taskeng_v0_lead_linkage`
- Default: `createHashMap`
- Decode fallback: if missing or wrong type, coerce to empty hashmap.

### Revision 3
- Key: `taskeng_v0_generation_buffers`
- Default: `createHashMap`
- Decode fallback: if missing or wrong type, coerce to empty hashmap.

## Backward compatibility requirements

- Saves without TASKENG keys must still initialize TASKENG to `RUN` on server init.
- Manual create flow must continue to work even when persistence payload is missing TASKENG sections.
- Migration should be idempotent: reloading a current schema save should not reapply steps.

## Required migration logs

- `TASKENG_MIGRATE_APPLY`
  - Emit once per applied step with migration step id and variable name.
- `TASKENG_MIGRATE_NOOP`
  - Emit when save schema revision is already at or above current revision.

## Implementation notes

- Decode path must set missionNamespace values before migration checks so post-migration code sees stable keys.
- Init path must always ensure defaults for migration-introduced keys (`active incident refs`, `lead linkage`, `generation buffers`, `thread store`).


### Revision 4
- Key: `taskeng_v0_thread_store`
- Default: `createHashMap`
- Decode fallback: if missing or wrong type, coerce to empty hashmap.
