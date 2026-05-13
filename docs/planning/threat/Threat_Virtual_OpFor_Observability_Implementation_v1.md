# Threat Virtual OpFor Observability Implementation v1

## Scope

This Epic 8 implementation slice publishes a server-built, read-only Virtual OpFor pool snapshot and documents how operators interpret pool state, caps, protected-zone rules, materialization/despawn behavior, and integration context.

- Snapshot contract: `ARC_pub_threatVirtualPoolSnapshot` (`schema = threat_virtual_opfor_obs_v1`)
- Public state embedding: `ARC_pub_state.threatVirtualPool`
- Console VM embedding: `ARC_consoleVM_payload.sections.threat.data.virtualPool`
- Authority boundary: server is the single writer; clients only consume read models

## Virtual pool model and states

Virtual OpFor records remain `type = VIRTUAL_OPFOR` in `threat_v0_records` with these states:

- `VIRTUAL_DORMANT`: no nearby player; may drift reposition outside protected zones.
- `VIRTUAL_ACTIVE`: player is in activation radius; eligible for physical materialization when additional gates pass.
- `PHYSICAL`: group is materialized with `spawnedUnits` refs and tracked until despawn/death cleanup returns to `VIRTUAL_DORMANT`.

`threat_v0_vgroup_active_index` is the physical-index companion for `PHYSICAL` records and is now observable for orphan diagnostics.

## Transitions, caps, and bounded behavior

The snapshot surfaces transition-relevant fields so behavior is diagnosable without adding controls:

- state counts (`virtual_dormant_count`, `virtual_active_count`, `physical_count`)
- materialized unit totals and capped materialized-row details
- active index count and orphan list
- capacity/cap indicators:
  - `pool_max_groups`
  - `physical_max_groups`
  - `city_physical_max_groups`
  - `spawn_budget_per_tick`

This PR does not retune balancing; it makes existing cap/tick behavior observable.

## Protected-zone interaction rules

Protected zones are explicit and surfaced as:

- `protectedZones.configured`
- `protectedZones.intersection_count`
- `protectedZones.physical_in_protected_count`
- `protectedZones.active_incident_zone`
- `protectedZones.active_incident_in_protected_zone`

Interpretation:
- Non-zero `intersection_count` indicates stored virtual positions currently overlap protected zones.
- Non-zero `physical_in_protected_count` indicates invariant breach evidence and should trigger immediate investigation.
- `active_incident_in_protected_zone = true` explains why incident coupling can suppress materialization.

## Snapshot field interpretation guide

| Field group | Purpose |
|---|---|
| `summary` | High-level enabled/status, virtual/physical counts, active-index health |
| `states` | Explicit state distribution for transition visibility |
| `capacity` | Cap/budget envelope currently applied by runtime |
| `protectedZones` | Exclusion policy visibility and overlap diagnostics |
| `materialization` | Active-index orphan diagnostics and bounded physical row sample |
| `locality` | Authority/locality interpretation (`authority=server`, loop status, shared keys) |
| `integration` | Incident + economy + threat event linkage hints for triage |
| `roleBoundaries` | Read-only boundary and deferred admin controls |

## Integration notes (threat economy and incident lifecycle)

- `integration.active_task_id` and `integration.active_incident_marker` align pool reads with current incident context.
- `integration.threat_last_event` links to the latest threat event envelope for timeline correlation.
- `integration.economy_snapshot_schema` confirms compatibility with Epic 7 economy observability snapshots.
- `integration.threat_ui_snapshot_updated_at` aligns operator timelines with Epic 3 threat UI surfacing freshness.

## Admin/control surface position

This PR intentionally implements **read-only diagnostics only**. New admin write/reset controls are deferred to avoid expanding remoteExec/control surface in this Epic 8 slice.

Any future controls must remain explicit, bounded, role-gated, server-mediated, logged, documented, and validated.

## Evidence plan and known validation gaps

- **PASS (static/local tooling):** schema contract, read-model publication, Console VM integration, and docs/check scripts.
- **PASS (local MP smoke):** may validate snapshot interpretation if runtime is available.
- **BLOCKED (not claimed here):**
  - dedicated server persistence/locality proof
  - JIP late-join consistency proof
  - restart rehydration/despawn correctness proof

These gaps remain for Epic 8 validation-closure work package (`E8-WP4`).
