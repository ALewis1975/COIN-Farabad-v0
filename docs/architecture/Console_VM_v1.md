# Console VM v1 Architecture

## Purpose

`Console_VM_v1` defines a normalized client-facing View Model (VM) contract for the console UI. It provides a stable payload shape over current `missionNamespace` variables so UI code can migrate from direct key reads to a single contract.

Design goals:
- Preserve current behavior during migration.
- Make freshness/staleness explicit per section.
- Keep server as single writer for authoritative state.
- Allow phased rollout with adapter shims and feature flags.

---

## 1) Versioning strategy

### 1.1 Contract ID
- Contract name: `Console_VM_v1`
- Version tuple:
  - `major`: breaking changes only
  - `minor`: backward-compatible field additions
  - `patch`: clarifications / non-shape behavior fixes

Recommended envelope fields:
```sqf
[
  ["schema", "Console_VM_v1"],
  ["version", [1,0,0]],
  ["builtAtServerTime", serverTime],
  ["sections", createHashMap]
]
```

### 1.2 Change rules
- **Major bump** (`2.x.x`): remove/rename fields, type changes, semantic reversals.
- **Minor bump** (`1.1.x`): add optional fields; existing fields remain valid.
- **Patch bump** (`1.0.1`): no shape change; docs/freshness logic bugfixes only.

### 1.3 Compatibility policy
- Clients must tolerate unknown fields.
- Clients must treat missing optional fields as default-safe values.
- Server keeps a compatibility adapter until all console tabs consume VM-only inputs.

### 1.4 Rollout status note
- Legacy migration toggles (`ARC_mig_enabled`, `ARC_mig_uiSnapshotOnly`, `ARC_mig_useRequestRouter`, `ARC_mig_disableLegacyActions`) were removed from active server bootstrap config because they are no longer consumed.
- VM migration now follows code-path rollout and review gates rather than runtime toggle flips in `initServer.sqf`.

---

## 2) Field-level source mapping (existing missionNamespace → VM fields)

### 2.1 Envelope and section metadata
| VM field | Source key(s) | Type | Notes |
|---|---|---|---|
| `meta.schema` | literal | `STRING` | `"Console_VM_v1"`. |
| `meta.version` | literal | `ARRAY[3]` | `[major, minor, patch]`. |
| `meta.builtAtServerTime` | `serverTime` at build | `SCALAR` | Server-authoritative build timestamp. |
| `meta.sectionFreshness.state.updatedAt` | `ARC_pub_stateUpdatedAt` | `SCALAR` | Primary freshness anchor for state summary. |

### 2.2 Active incident section (`sections.incident`)
| VM field | Source key(s) | Type | Default/fallback |
|---|---|---|---|
| `id` | `ARC_activeTaskId` | `STRING` | `""` |
| `displayName` | `ARC_activeIncidentDisplayName` | `STRING` | `""` |
| `type` | `ARC_activeIncidentType` | `STRING` | `""` |
| `posATL` | `ARC_activeIncidentPos` | `ARRAY` | `[]` |
| `accepted` | `ARC_activeIncidentAccepted` | `BOOL` | `false` |
| `acceptedByGroup` | `ARC_activeIncidentAcceptedByGroup` | `STRING` | `""` |
| `closeReady` | `ARC_activeIncidentCloseReady` | `BOOL` | `false` |
| `sitrepSent` | `ARC_activeIncidentSitrepSent` | `BOOL` | `false` |
| `sitrepSummary` | `ARC_activeIncidentSitrepSummary` | `STRING` | `""` |
| `sitrepDetails` | `ARC_activeIncidentSitrepDetails` | `STRING` | `""` |
| `sitrepFrom` | `ARC_activeIncidentSitrepFrom` | `STRING` | `""` |
| `sitrepFromGroup` | `ARC_activeIncidentSitrepFromGroup` | `STRING` | `""` |
| `suggestedResult` | `ARC_activeIncidentSuggestedResult` | `STRING` | `""` |
| `closeReason` | `ARC_activeIncidentCloseReason` | `STRING` | `""` |
| `holdMain` | `ARC_activeIncidentHoldMain` | `BOOL` | `false` if missing |

### 2.3 Follow-on section (`sections.followOn`)
| VM field | Source key(s) | Type | Default/fallback |
|---|---|---|---|
| `request` | `ARC_activeIncidentFollowOnRequest` | `ARRAY` | `[]` |
| `summary` | `ARC_activeIncidentFollowOnSummary` | `STRING` | `""` |
| `lead.id` | `ARC_activeIncidentFollowOnLeadId` | `STRING/NIL` | `""` for UI |
| `lead.name` | `ARC_activeIncidentFollowOnLeadName` | `STRING/NIL` | `""` |
| `lead.posATL` | `ARC_activeIncidentFollowOnLeadPos` | `ARRAY/NIL` | `[]` |
| `lead.grid` | `ARC_activeIncidentFollowOnLeadGrid` | `STRING/NIL` | `""` |

### 2.4 Queue/orders/intel section (`sections.ops`)
| VM field | Source key(s) | Type | Default/fallback |
|---|---|---|---|
| `queue.pending` | `ARC_pub_queuePending` | `ARRAY` | `[]` |
| `queue.tail` | `ARC_pub_queueTail` | `ARRAY` | `[]` |
| `orders.active` | `ARC_pub_orders` | `ARRAY` | `[]` |
| `intel.log` | `ARC_pub_intelLog` | `ARRAY` | `[]` |
| `ops.log` | `ARC_pub_opsLog` | `ARRAY` | `[]` |
| `leads.pool` | `ARC_leadPoolPublic` | `ARRAY` | `[]` |

### 2.5 Campaign summary section (`sections.stateSummary`)
| VM field | Source key(s) | Type | Notes |
|---|---|---|---|
| `pairs` | `ARC_pub_state` | `ARRAY[pairs]` | Preserve current pair-array shape in v1. |
| `updatedAt` | `ARC_pub_stateUpdatedAt` | `SCALAR` | Staleness anchor for summaries/dashboards. |

### 2.6 Access/config section (`sections.access`)
| VM field | Source key(s) | Type | Default/fallback |
|---|---|---|---|
| `omniTokens` | `ARC_consoleOmniTokens` | `ARRAY` | `["OMNI"]` |
| `hqTokens` | `ARC_consoleHQTokens` | `ARRAY` | project default list |
| `terminal.varNames` | `ARC_consoleTerminalVarNames` | `ARRAY` | `[]` |
| `terminal.radiusM` | `ARC_consoleTerminalRadiusM` | `SCALAR` | `4` |
| `terminal.markerNames` | `ARC_consoleTerminalMarkers` | `ARRAY` | `[]` |
| `terminal.markerRadiusM` | `ARC_consoleTerminalMarkerRadiusM` | `SCALAR` | `5` |
| `terminal.mobileVarNames` | `ARC_consoleMobileTerminalVarNames` | `ARRAY` | `["remote_ops_vehicle"]` |
| `terminal.mobileRadiusM` | `ARC_consoleMobileTerminalRadiusM` | `SCALAR` | `5` |
| `requiredItems` | `ARC_consoleRequiredItems` | `ARRAY` | `[]` |
| `noItemRequired` | `ARC_consoleNoItemRequired` | `BOOL` | `false` |

### 2.7 CIVSUB visibility section (`sections.civsub`)
| VM field | Source key(s) | Type | Default/fallback |
|---|---|---|---|
| `enabled` | `civsub_v1_enabled` | `BOOL` | `false` |
| `districtSnapshots` | `civsub_v1_districts` | `HASHMAP` | `createHashMap` / empty map |

---

## 3) Freshness metadata rules

### 3.1 Core rule: section-level freshness, not global guesswork
Each VM section must carry:
- `updatedAt`: authoritative server timestamp for that section.
- `source`: source family (e.g., `ARC_pub_state`, `ARC_pub_orders`, `incident_live`).
- `staleAfterS`: soft TTL used only for UI warnings; never for destructive logic.

Example section wrapper:
```sqf
[
  ["data", _sectionData],
  ["freshness", [
    ["updatedAt", _ts],
    ["staleAfterS", 15],
    ["source", "ARC_pub_orders"]
  ]]
]
```

### 3.2 Timestamp derivation precedence
1. Use an explicit companion timestamp key when available (e.g., `ARC_pub_stateUpdatedAt`).
2. Else use producer-local timestamp captured at publish/build time.
3. Else fall back to VM `meta.builtAtServerTime` and mark `freshness.derived = true`.

### 3.3 Recommended TTL defaults (UI hint only)
- `incident`: `5s`
- `queue/orders`: `10s`
- `intel/ops log`: `15s`
- `lead pool`: `15s`
- `stateSummary`: `20s`
- `access/config`: `60s`
- `civsub district snapshots`: `2 * civsub_v1_tick_s` (if available), else `120s`

### 3.4 Staleness handling
- If `(clientNowServerEstimate - updatedAt) > staleAfterS`:
  - keep rendering last known data,
  - show a non-blocking stale badge,
  - allow explicit manual refresh actions where applicable.
- Do **not** auto-clear lists on staleness; clearing causes false “no data” states during network jitter.

### 3.5 Consistency guard
When building VM:
- Snapshot all source keys first into locals.
- Build sections from locals only.
- Emit once, atomically (`setVariable` VM payload + VM updatedAt marker in same publish function).

---

## 4) Backward-compatibility adapter notes (phased migration)

### 4.1 Adapter role
Provide `ARC_fnc_consoleVmAdapterV1` that:
- Reads legacy `missionNamespace` keys.
- Produces `Console_VM_v1` payload.
- Optionally mirrors critical derived values back to legacy keys during transition (one-way, server-owned).

### 4.2 Phased migration plan

#### Phase A — Observe only
- Keep all existing UI reads intact.
- Build and publish VM side-by-side for audit.
- Compare VM projections vs current rendered values in debug logging.

#### Phase B — Read switch (tab-by-tab)
- Migrate one console tab at a time to VM reads.
- Retain fallback path:
  - if VM missing/invalid section → read legacy keys.
- Do not alter action/request routes yet.

#### Phase C — Write path convergence
- Route console actions through VM-aware request router.
- Legacy action entry points call router shim (no behavior divergence).

#### Phase D — Legacy deprecation
- Confirm all tabs/actions are VM-backed before removing legacy shims.
- Remove direct missionNamespace reads from UI paint/action functions.
- Keep a short-lived rollback toggle to re-enable adapter fallback.

### 4.3 Adapter safety rules
- Type-guard every source key (`isEqualType` checks).
- Normalize nil/empty variants to canonical VM defaults.
- Preserve existing enum/string tokens exactly in v1.
- Never mutate authoritative gameplay state in client adapter code.

### 4.4 Rollback strategy
If regression appears:
1. Revert affected tab to legacy-read path in code (no runtime migration toggle is available).
2. Keep VM publishing enabled for diagnostics.
3. Capture VM payload + freshness logs for the failing tab.
4. Fix mapping/freshness issue, then re-enable by tab.

### 4.5 Known edge cases to cover in adapter tests
- No active incident (`ARC_activeTaskId == ""`).
- SITREP received but closeout not ready.
- Follow-on lead fields set to `nil` vs empty string/array.
- Queue snapshot temporarily empty during broadcast churn.
- CIVSUB disabled with stale district cache on client.

---

## 5) Minimum acceptance criteria for Console_VM_v1 adoption
- VM payload always publishes valid envelope + section freshness metadata.
- Each mapped field resolves from documented source key with safe default.
- At least one tab (recommended: Dashboard) can run VM-first with no user-visible regression.
- Feature flags allow immediate rollback to legacy read paths.
- Debug logs show section freshness and stale-state decisions.

