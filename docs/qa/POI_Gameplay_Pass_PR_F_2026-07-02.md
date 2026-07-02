# PR F POI Gameplay Pass

Status: catalog-only first gameplay pass using corrected POI anchors.

## Scope

This PR adds small POI-driven incident catalog entries that target the corrected Grand Mosque, Belle Foille Hotel, and Karkanak Prison anchors.

## Added incidents

Grand Mosque:
- `Checkpoint: TNP Cordon at Grand Mosque` at `ARC_loc_GrandMosqueOuterCordon`
- `Civil: Vendor Dispute at Mosque Market Edge` at `ARC_loc_GrandMosqueVendorStrip`

Belle Foille Hotel:
- `Civil: Hotel Security Interview` at `ARC_loc_BelleFoilleHotelSecurityPost`

Karkanak Prison:
- `Escort: EPW Handoff at Karkanak Prison` at `prison_entry_office`

## Boundaries

No `mission.sqm` edits.
No new task engine logic.
No persistence changes.
No CIVSUB, SitePop engine, AIRBASE, Threat, or UI changes.
No ambient population count changes.

## Why these tasks

These entries exercise the corrected anchors from PR D and PR E without adding a new subsystem. They should produce more believable task locations around the mosque/hotel/prison micro-zones while continuing to use the existing incident generation path.

## Dedicated MP smoke test

1. Start dedicated server and confirm no RPT compile errors from `data/incident_markers.sqf`.
2. Generate incidents until one of the new POI rows appears, or temporarily force-select a row in a local test build.
3. Confirm each marker resolves through `ARC_fnc_worldResolveMarker` / `allMapMarkers`:
   - `ARC_loc_GrandMosqueOuterCordon`
   - `ARC_loc_GrandMosqueVendorStrip`
   - `ARC_loc_BelleFoilleHotelSecurityPost`
   - `prison_entry_office`
4. Accept a task and confirm route/local support behavior remains normal.
5. JIP a second client during an active task and confirm task state is visible and no duplicate task is generated.

## Regression risk

Low. This is a catalog-only gameplay pass. Main risk is task weighting/frequency, since the incident catalog has more candidates at these POIs.
