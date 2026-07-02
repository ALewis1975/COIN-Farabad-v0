# PR D Mosque Hotel TNP HQ Anchors

Status: data and SitePop anchor implementation.

## Scope

This PR adds runtime anchor markers for the Grand Mosque, Belle Foille Hotel, and TNP Farabad HQ micro-zone. It does not edit mission.sqm and does not change population counts.

## Added runtime anchors

Grand Mosque:
- ARC_loc_GrandMosqueCourtyard
- ARC_loc_GrandMosqueVendorStrip
- ARC_loc_GrandMosqueOuterCordon
- ARC_loc_GrandMosqueParking

Belle Foille Hotel:
- ARC_loc_BelleFoilleHotelEntrance
- ARC_loc_BelleFoilleHotelSecurityPost
- ARC_loc_BelleFoilleHotelParking

TNP HQ:
- ARC_loc_TNPFarabadHQ
- ARC_loc_TNPFarabadHQFrontage
- ARC_loc_TNPFarabadHQCordon

These are created by ARC_fnc_worldRegisterLocations from data/farabad_world_locations.sqf.

## SitePop changes

Grand Mosque and Belle Foille Hotel SitePop groups now use the optional seventh spawnAnchor field. Counts are unchanged.

Grand Mosque:
- elder and worshipper anchor to the courtyard
- vendor anchors to the vendor strip
- TNP outer security anchors to the outer cordon
- parked civilian cars anchor to parking

Belle Foille Hotel:
- staff and guests anchor to the entrance
- security anchors to the security post
- parked civilian cars anchor to parking

TNP HQ anchors are provided for future task placement and cordon logic; this PR does not add a new SitePop template or task catalog entry for TNP HQ.

## Regression risk

Low to moderate. The risk is anchor coordinate quality, not system behavior. If an anchor marker is missing at runtime, ARC_fnc_sitePopBuildGroup falls back to site center and logs a warning.

## Dedicated MP smoke test

1. Start dedicated server and confirm no RPT compile errors from data/farabad_world_locations.sqf, data/farabad_spawn_patterns.sqf, or data/farabad_site_templates.sqf.
2. Confirm the new ARC_loc_* anchors exist after world init.
3. Move a player into the Grand Mosque activation radius and confirm SitePop spawns the same count ranges as before.
4. Confirm mosque vendors, worshippers, TNP outer security, and parked cars cluster near their role anchors.
5. Move a player into the Belle Foille Hotel activation radius and confirm hotel staff, guests, security, and cars cluster near their anchors.
6. JIP a second client and confirm no duplicate SitePop activation or public-state errors.
