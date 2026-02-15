# EPIC 3 — CIVSUB SITREP Annex Contract Compliance

## Contract
When `civsub_v1_enabled=true`, every SITREP submission must include a CIVSUB annex payload.

## Patch summary
- Updated `fn_tocReceiveSitrep.sqf` to enforce non-empty annex generation via a deterministic fallback chain:
  1. District from SITREP position
  2. Fallback to `activeIncidentCivsubDistrictId`
  3. Fallback to explicit `District: UNKNOWN` annex text
- Added persistent default key `activeIncidentSitrepAnnexCivsub` in `fn_stateInit.sqf`.
- Added bootstrap mirror publish for `ARC_activeIncidentSitrepAnnexCivsub` in `fn_bootstrapServer.sqf`.

## Expected runtime behavior
- No empty CIVSUB annex when CIVSUB is enabled.
- JIP clients receive latest annex mirror from bootstrap and live SITREP updates.
