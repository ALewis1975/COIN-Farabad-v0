# Farabad TASKENG/SITREPSYS Snapshot Payload Baseline

**Document status:** implementation baseline (snapshot contract)  
**Scope:** CORE snapshot sections `[8]` SITREPSYS + `[10]` TASKENG  
**Compatibility intent:** readers must support both legacy array payloads (`schema_ver=0/implicit`) and tagged v1 map payloads.

---

## 1) Design goals

- Introduce explicit payload schema tags + versions for TASKENG and SITREPSYS sections.
- Move major top-level payload blocks to keyed map-like structures for readability and safer evolution.
- Keep bounded compact row arrays where they are performance-sensitive and already bounded.
- Require fail-soft clients (log warning + continue) instead of hard index assumptions.

---

## 2) Snapshot index placement (unchanged)

CORE snapshot top-level indices remain:

- `[8]` = `sitrepsysSnap`
- `[10]` = `taskengSnap`

The top-level index contract is unchanged to preserve wire compatibility.

---

## 3) TASKENG payload contract

### v1 (schema-tagged map)

`taskengSnap` is a HashMap with:

- `schema` (STRING): `"TASKENG_SNAP"`
- `schema_ver` (NUMBER): `1`
- `enabled` (BOOL)
- `subsystem_ver` (NUMBER)
- `state` (STRING)
- `rev` (NUMBER)
- `open_count` (NUMBER)
- `closed_count` (NUMBER)
- `rows` (ARRAY of bounded compact rows)
- `toc` (HashMap):
  - `gate` (BOOL)
  - `rows` (ARRAY of bounded compact rows)
- `hist_rows` (ARRAY of bounded compact rows)

### Compact row layouts (retained)

These remain array-rows for bounded/high-frequency UI rendering:

- `rows[]` item: `[taskId, state, acceptingUnitKey, marker, updatedTs, followonToken]`
- `toc.rows[]` item: `[taskId, state, acceptingUnitKey, marker, updatedTs]`
- `hist_rows[]` item: existing TASKENG history compact event row (unchanged).

### Legacy fallback decode

Readers must continue to decode legacy array payload as:

`[enabled, subsystem_ver, state, rev, open_count, closed_count, rows, toc_gate, toc_rows, hist_rows]`

---

## 4) SITREPSYS payload contract

### v1 (schema-tagged map)

`sitrepsysSnap` is a HashMap with:

- `schema` (STRING): `"SITREPSYS_SNAP"`
- `schema_ver` (NUMBER): `1`
- `enabled` (BOOL)
- `subsystem_ver` (NUMBER)
- `state` (STRING)
- `rev` (NUMBER)
- `open_count` (NUMBER)
- `closed_count` (NUMBER)
- `rows` (ARRAY of bounded compact rows)
- `meta_rows` (ARRAY of bounded compact rows)

### Compact row layouts (retained)

- `rows[]` item: `[sitrepId, taskId, state, reportingUnitKey, updatedTs]`
- `meta_rows[]` item (TOC review helper): `[taskId, sitrepId, reportingUnitKey, callsign, submittedTs, submittedWorldDate, recCoa, recRtbReasons[], reqSupport[], otherText, lace[4], narrativeLen]`

### Legacy fallback decode

Readers must continue to decode legacy array payload as:

`[enabled, subsystem_ver, state, rev, open_count, closed_count, rows, meta_rows]`

---

## 5) Reader behavior requirements

- Detect schema by type + tags:
  - HashMap + expected `schema`/`schema_ver` ⇒ use keyed decode.
  - Array / missing tags ⇒ decode legacy indexes.
- On missing/invalid fields:
  - log warning,
  - substitute safe defaults,
  - continue rendering (no hard failure).
- Treat row arrays as optional/bounded; absent rows should render empty-state UI.

---

## 6) Evolution rules

- Future incompatible change increments `schema_ver`.
- Maintain fallback decode for at least one prior version during migration windows.
- Prefer keyed top-level fields for new data; only use row arrays for bounded hot-path tabular data.
