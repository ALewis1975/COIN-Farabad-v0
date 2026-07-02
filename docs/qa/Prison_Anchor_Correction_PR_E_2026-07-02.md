# PR E Prison Anchor Correction

Status: data-only prison anchor correction. No SitePop engine rewrite and no mission.sqm edit.

## Scope

This PR validates the Karkanak Prison SitePop anchors already present in the mission and corrects template-level anchor assignments that could stack support roles in the admin block or allow support civilians to bleed across the prison footprint.

## Corrections

- `escort` now anchors to `prison_entry_office` instead of `prison_admin_offices`.
- `reaction` now anchors to `prison_central_guard_tower` instead of `prison_admin_offices`.
- `contractor` now anchors to `prison_entry_office` instead of using site-wide placement.
- Population count ranges are unchanged.
- Existing guard, hospital, dormitory, intake, and holding anchors are retained.

## Validation notes

The generated marker index confirms the prison anchor set exists:
- `prison_admin_offices`
- `prison_central_guard_tower`
- `prison_dorm_01` through `prison_dorm_04`
- `prison_entry_office`
- `prison_guard_tower_1`
- `prison_guard_tower_2`
- `prison_holding_area`
- `prison_hospital`
- `prison_intake_01`

`prison_intake_02` exists but is not used by the current template.
`prison_intake_03` exists in the generated marker index but is offsite at the airbase and is deliberately not used.

## Boundaries

No `mission.sqm` edits.
No population count increase.
No new task catalog entries.
No SitePop engine changes.
No CIVSUB, Threat, AIRBASE, persistence, or UI changes.

## Dedicated MP smoke test

1. Start a dedicated server and confirm no RPT compile errors from `data/farabad_site_templates.sqf`.
2. Move a player into Karkanak Prison activation radius.
3. Confirm SitePop activates once and the same role count ranges spawn.
4. Confirm `escort` units are near the entry office / vehicle-search area.
5. Confirm `reaction` units are near the central guard tower / internal reserve area.
6. Confirm `contractor` civilians no longer wander site-wide at activation.
7. Leave the despawn radius and confirm cleanup/despawn behavior remains unchanged.
8. JIP a second client during active prison SitePop and confirm no duplicate activation.

## Regression risk

Low to moderate. This is a template-only anchor assignment change. If an anchor marker is missing at runtime, `ARC_fnc_sitePopBuildGroup` falls back to the site center and logs a warning.
