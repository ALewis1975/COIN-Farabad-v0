/*
    farabad_site_profiles.sqf

    Site metadata for the PSI (Persistent Site Intelligence) subsystem.
    Loaded by ARC_fnc_sitePopInit and stored as ARC_sitePopSiteProfiles.

    Returns: HASHMAP keyed by siteId (STRING).
             Each value is a profile HASHMAP with the following keys:

        districtId       STRING  - CIVSUB district ID (D01..D20)
        siteType         STRING  - GOV_PRISON | GOV_PALACE | GOV_EMBASSY | ...
        owner            STRING  - GOV | INDEP | OPFOR
        adaptationPolicy STRING  - Policy tag consumed by ARC_fnc_sitePopGetSpawnModifiers:
                                     PRISON_HARDENED — raise defender count/alert, never add OPFOR
                                     PALACE_HARDENED — raise guard count/alert, never add OPFOR
                                     EMBASSY_HARDENED — raise guard count/alert, never add OPFOR
                                     DEFAULT — generic site policy

    NOTE: districtId values should match the canonical IDs in
          ARC_fnc_civsubDistrictsCreateDefaults (D01..D20).
          Placeholder IDs are noted inline; update when mission geography is confirmed.
*/

private _profiles = createHashMap;

// ---------------------------------------------------------------------------
// KARKANAK PRISON — D08 (Karkanak district)
// ---------------------------------------------------------------------------
private _kProfile = createHashMap;
_kProfile set ["districtId",       "D08"];
_kProfile set ["siteType",         "GOV_PRISON"];
_kProfile set ["owner",            "GOV"];
_kProfile set ["adaptationPolicy", "PRISON_HARDENED"];
_profiles set ["KarkanakPrison", _kProfile];

// ---------------------------------------------------------------------------
// PRESIDENTIAL PALACE — D01 (Farabad; verify against mission geography)
// ---------------------------------------------------------------------------
private _ppProfile = createHashMap;
_ppProfile set ["districtId",       "D01"];
_ppProfile set ["siteType",         "GOV_PALACE"];
_ppProfile set ["owner",            "GOV"];
_ppProfile set ["adaptationPolicy", "PALACE_HARDENED"];
_profiles set ["PresidentialPalace", _ppProfile];

// ---------------------------------------------------------------------------
// EMBASSY COMPOUND — D01 (Farabad; verify against mission geography)
// ---------------------------------------------------------------------------
private _ecProfile = createHashMap;
_ecProfile set ["districtId",       "D01"];
_ecProfile set ["siteType",         "GOV_EMBASSY"];
_ecProfile set ["owner",            "GOV"];
_ecProfile set ["adaptationPolicy", "EMBASSY_HARDENED"];
_profiles set ["EmbassyCompound", _ecProfile];

_profiles
