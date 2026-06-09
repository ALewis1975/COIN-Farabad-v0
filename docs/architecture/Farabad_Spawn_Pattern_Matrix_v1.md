# Farabad Spawn-Pattern Matrix (Issue #633, Steps 1–2)

This document describes the data-driven Incident / Lead / site **spawn-pattern
matrix** and its **audit** diagnostics. It corresponds to steps 1–2 of the issue
#633 suggested implementation sequence: *"Add the spawn-pattern schema and audit
function without changing gameplay behavior"* and *"map all existing Incident and
civic catalog rows to pattern IDs."*

## What this delivers

- A single source of truth that answers, for every Incident, Lead, named
  location, and terrain site type, the four design questions from #633:
  1. **Where is this?** — marker / location / terrain site / district.
  2. **What is this place supposed to be?** — a *purpose tag*.
  3. **What belongs here before the task?** — the *baseline population* pattern.
  4. **What changes because of the task?** — the *incident / lead overlay*.
- A read-only **audit** that resolves every catalog row and reports coverage and
  warnings, with no spawning and no state mutation.

This step is intentionally **gameplay-neutral**. No transient overlay spawning is
wired up yet; the matrix is data and the audit is diagnostics only.

## Files

| File | Role |
| --- | --- |
| `data/farabad_spawn_patterns.sqf` | The spawn-pattern matrix (data only). |
| `functions/world/fn_worldSpawnPatternAudit.sqf` | `ARC_fnc_worldSpawnPatternAudit` — read-only audit. |
| `tests/static/spawn_pattern_matrix_contract_checks.sh` | Static coverage + read-only contract test (wired into CI). |

## Matrix structure

`data/farabad_spawn_patterns.sqf` returns an array of `[key, value]` pairs
(consumed via a compiled `getOrDefault` helper for sqflint compatibility):

- `purposePatterns` — `[purposeTag, patternDef]` baseline ambient population and
  props for each place purpose.
- `locationPurposes` — `[locationId, purposeTag]` for every id in
  `data/farabad_world_locations.sqf` (or the `NO_BASELINE_POP` sentinel).
- `siteTypePurposes` — `[terrainSiteType, purposeTag]` for every exported
  terrain site type.
- `incidentOverlays` — `[incidentType, overlayDef]` task overlay layered on the
  baseline for each incident type in `data/incident_markers.sqf`.
- `leadOverlays` — `[leadTag, overlayDef]` lead-driven overlay (driven by lead
  fields, not display-name string checks).
- `civicMissionOverlays` — `[subtype, overlayDef]` purpose-specific overlay keyed
  by the `subtype` field of every record in
  `data/coin_civic_mission_catalog.sqf` (aid tables/crowds, doctors/ambulance,
  government staff, work crews, gate flow, etc.) so structured civic missions get
  context the bare `incidentType` overlay cannot express.

### Purpose tags

`RESIDENTIAL`, `MARKET`, `RELIGIOUS`, `MEDICAL`, `GOVERNMENT`, `HOTEL`,
`SECURITY`, `INDUSTRIAL`, `OIL_GAS`, `POWER`, `PORT`, `MINE`, `CONSTRUCTION`,
`AGRICULTURAL`, `MILITARY`, `PRISON`, `RURAL_HAMLET`, `CHECKPOINT`, `MSR_ROAD`,
plus the sentinel `NO_BASELINE_POP` for places that intentionally receive no
baseline ambient population (e.g. river markers).

### Class pools

Role tags in the matrix are **symbolic**. Concrete `CfgVehicles` class pools are
*not* declared here; the later overlay-spawning phase resolves them from the
SitePop pools / faction enumeration in `data/farabad_site_templates.sqf`, which
already filter invalid classes against the live mod preset. This keeps the matrix
free of class-pool drift and missing-class RPT spam.

## Audit

`ARC_fnc_worldSpawnPatternAudit` (server-only, read-only):

- Resolves every named location, terrain site type, Incident catalog row, and
  structured civic-mission row against the matrix.
- Reports, per row: resolved reference, purpose tag, selected pattern, combined
  AI count range, object count range, placement strategy, cleanup owner, and
  per-row warnings.
- Collects warnings for: missing purpose mapping, missing pattern, missing
  marker, missing incident overlay, missing civic-subtype overlay, or no
  baseline population.

Returns `[["rows", …], ["warnings", …], ["summary", …]]` where `summary` is
`[totalRows, locationCount, siteTypeCount, incidentRowCount, civicRowCount,
warningCount]`. Pass `true` for a verbose `diag_log` dump of every row and
warning. Civic rows carry the civic `subtype` in the row's `incidentType` field.

## Rollout toggles

All default **off** so the mission keeps its current type-driven incident
execution and existing SitePop behaviour until each later phase is validated
(set in `initServer.sqf`):

```sqf
ARC_spawnPatternsEnabled         = false; // master gate + one-shot audit log
ARC_incidentOverlaySpawnsEnabled = false; // transient overlay spawning (later)
ARC_sitePurposeExpansionEnabled  = false; // expanded SitePop baselines (later)
```

When `ARC_spawnPatternsEnabled` is `true`, `initServer.sqf` runs a one-shot
verbose audit so coverage/warnings appear in the RPT. The audit performs no
spawning regardless of toggle state.

## Validation

`tests/static/spawn_pattern_matrix_contract_checks.sh` (wired into
`.github/workflows/arma-preflight.yml`) verifies:

- Data + audit files exist; audit registered in `CfgFunctions`.
- Rollout toggles present and default `false`.
- Audit is server-only and read-only (no `createUnit` / `createVehicle` /
  `publicVariable` / `remoteExec` / …).
- Every named location and terrain site type maps to a purpose that has a
  pattern; every incident type and required lead tag has an overlay; every
  structured civic-mission subtype has an overlay.
- The changed SQF avoids known sqflint-compat pitfalls.

## Next phases (not in these steps)

3. Expand SitePop templates for high-value named locations.
4. Transient Incident/Lead overlay spawning behind `ARC_incidentOverlaySpawnsEnabled`.
5. Checkpoint traffic / civilian flow behaviour.
6. Construction and industrial purpose patterns at runtime.
7. MP validation and count tuning.
