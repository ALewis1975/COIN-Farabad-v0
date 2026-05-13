# Threat UI Surfacing v1

## Scope

This implementation adds a **read-only threat surfacing contract** for TOC/S2/player-adjacent workflows:

- Replicated snapshot: `ARC_pub_threatUiSnapshot`
- Console VM section: `ARC_consoleVM_payload.sections.threat`
- Client surface: `ARC_THREAT` diary subject / `Threat Picture` record

The dedicated server remains the single authority for shared threat state. Clients render snapshots only.

## Display contract and canonical source mapping

| Displayed field | Snapshot key | Canonical source key |
|---|---|---|
| Threat ID | `list.*[].threat_id` | `threat_v0_records[].threat_id` |
| State | `list.*[].state` / `state_label` | `threat_v0_records[].state` |
| Family / type | `list.*[].type` / `type_label` | `threat_v0_records[].type` |
| Subtype | `list.*[].subtype` | `threat_v0_records[].subtype` |
| District | `list.*[].district_id` | `threat_v0_records[].links.district_id` |
| Task link | `list.*[].task_id` | `threat_v0_records[].links.task_id` |
| Lead link | `list.*[].lead_id` | `threat_v0_records[].links.lead_id` |
| Incident link | `list.*[].incident_id` | `threat_v0_records[].links.incident_id` |
| Grid | `list.*[].grid` | `threat_v0_records[].area.grid` |
| Marker | `list.*[].marker` | `threat_v0_records[].area.marker` |
| Last updated | `list.*[].updated_at` | `threat_v0_records[].updated_ts` |
| World presence | `list.*[].world_spawned` / `world_object_count` | `threat_v0_records[].world.spawned` / `world.objects_net_ids` |
| Intel level | `list.*[].intel_level` | `threat_v0_records[].telegraphing.intel_level` |
| Outcome result | `list.*[].outcome_result` | `threat_v0_records[].outcome.result` |
| Open count | `summary.open_count` | `threat_v0_open_index` |
| Closed count | `summary.closed_count` | `threat_v0_closed_index` |
| Event feed rows | `events[]` | `threat_v0_events_public[]` |

## Views, sorting, filters, and freshness

- Default view: `OPEN`
- Available views: `OPEN`, `FOLLOW_ON`, `RECENTLY_CLOSED`, `EVENT_FEED`
- Default sort: `updated_at DESC`
- Filter sets:
  - `views.filters.states`
  - `views.filters.types`
  - `views.filters.districts`
- Freshness contract:
  - Snapshot timestamp: `updatedAt`
  - UI stale threshold: `staleAfterS = 30`
  - If stale, clients keep the last known picture visible and show a stale warning instead of clearing rows.

## Event to UI mapping

| Canonical event | UI bucket | Operator meaning |
|---|---|---|
| `THREAT_CREATED` | `CREATE` | New threat row opened for triage |
| `THREAT_CREATED_FROM_LEAD` | `CREATE` | Lead promoted into a tracked threat |
| `THREAT_STATE_CHANGED` | `UPDATE` or `FOLLOW_ON` | State moved; `FOLLOW_ON` is used for `STAGED`, `DISCOVERED`, `DETONATED`, `NEUTRALIZED`, `INTERDICTED` |
| `THREAT_CLOSED` | `CLOSE` | Threat no longer needs active watch |
| `THREAT_CLEANED` | `CLEANUP` | World artifacts/cleanup complete |

## Empty, stale, and error state rules

- **No data yet:** render `emptyState` guidance and wait for the next server publish.
- **No open threats:** keep event feed and recently closed rows visible; do not present this as an authorization or writer state.
- **Stale snapshot:** keep last known data, show stale warning, and advise operator refresh/verification workflow.
- **Error state:** render the last known data plus `errorState` guidance; clients never attempt to repair or write authoritative threat state.

## Role-based visibility and action boundaries

- **Read-only surfaces**
  - `ARC_THREAT` diary record
  - `ARC_pub_threatUiSnapshot`
  - `Console_VM_v1.sections.threat`
- **Operator actions**
  - Verify reports, request follow-on work, and use existing TOC/S2 lead/intel/queue tools.
- **Admin tooling hooks**
  - Existing debug inspector / `ARC_pub_debug` threat fields remain diagnostic only.
  - No client UI path writes `missionNamespace` threat state directly.

## Operator triage / verification workflow

1. Check freshness first (`updatedAt` vs `staleAfterS`).
2. Review the `OPEN` board by district/state and identify the top active rows.
3. Review the `FOLLOW_ON` subset for `STAGED`, `DISCOVERED`, `DETONATED`, `NEUTRALIZED`, and `INTERDICTED` outcomes.
4. Use existing TOC/S2 tools to request or verify follow-on work; do not treat the UI as an authoring surface.
5. Before clearing the watch, verify `RECENTLY_CLOSED` rows and the `EVENT_FEED` for close/cleanup outcomes.
