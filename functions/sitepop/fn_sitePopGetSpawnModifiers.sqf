/*
    ARC_fnc_sitePopGetSpawnModifiers

    Server: build a spawn-context (ctx) HashMap for a site based on its persistent
    state history and site profile. The ctx is passed as the 4th argument to each
    ARC_fnc_sitePopBuildGroup call during ARC_fnc_sitePopSpawnSite.

    Modifier logic is gated by siteType from ARC_sitePopSiteProfiles:
        GOV_PRISON   — raises tower/reaction manning as adaptationLevel increases.
                       Never introduces OPFOR reinforcement.
        GOV_PALACE   — raises guard manning on repeated contact. Never adds OPFOR.
        GOV_EMBASSY  — same as PALACE_HARDENED. Never adds OPFOR.
        DEFAULT      — no modifiers; returns empty HashMap.

    Ctx schema (returned HASHMAP keys):
        "roleDelta"   HASHMAP — roleTag → INTEGER count delta (positive = extra unit(s)).
                                Only roles that need modification are present.

    Params:
        0: STRING — siteId

    Returns: HASHMAP — spawn-context modifier map (may be empty if no modifiers apply).
*/

if (!isServer) exitWith { createHashMap };

params [["_siteId", "", [""]]];
if (_siteId isEqualTo "") exitWith { createHashMap };

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _ctx = createHashMap;

// ---------------------------------------------------------------------------
// Read site profile
// ---------------------------------------------------------------------------
private _profiles = missionNamespace getVariable ["ARC_sitePopSiteProfiles", createHashMap];
if (!(_profiles isEqualType createHashMap)) exitWith { _ctx };

private _profile = [_profiles, _siteId, createHashMap] call _hg;
if (!(_profile isEqualType createHashMap)) exitWith { _ctx };

private _siteType = [_profile, "siteType",         "DEFAULT"] call _hg;
private _policy   = [_profile, "adaptationPolicy", "DEFAULT"] call _hg;

if (!(_siteType isEqualType "")) then { _siteType = "DEFAULT"; };
if (!(_policy   isEqualType "")) then { _policy   = "DEFAULT"; };

// ---------------------------------------------------------------------------
// Read site state
// ---------------------------------------------------------------------------
private _siteStates = missionNamespace getVariable ["ARC_sitePopSiteStates", createHashMap];
if (!(_siteStates isEqualType createHashMap)) exitWith { _ctx };

private _siteState = [_siteStates, _siteId, createHashMap] call _hg;
if (!(_siteState isEqualType createHashMap)) exitWith { _ctx };

private _adaptLevel   = [_siteState, "adaptationLevel",  0] call _hg;
private _guardCas     = [_siteState, "guardCasualties",  0] call _hg;
if (!(_adaptLevel isEqualType 0)) then { _adaptLevel = 0; };
if (!(_guardCas   isEqualType 0)) then { _guardCas   = 0; };

// ---------------------------------------------------------------------------
// Apply modifiers by policy
// ---------------------------------------------------------------------------
switch (_policy) do
{
    case "PRISON_HARDENED":
    {
        // Level 1+ (1-5 cumulative guard casualties): +1 on all three tower groups.
        // Level 2+ (6-10 casualties): +1 on reaction group as well.
        // Level 3+ (11+ casualties): towers get +2.
        // GOV sites NEVER receive OPFOR reinforcement — only BLUFOR headcount changes.
        private _towerDelta    = 0;
        private _reactionDelta = 0;

        if (_adaptLevel >= 1) then { _towerDelta    = 1; };
        if (_adaptLevel >= 2) then { _reactionDelta = 1; };
        if (_adaptLevel >= 3) then { _towerDelta    = 2; };

        if (_towerDelta > 0 || { _reactionDelta > 0 }) then
        {
            private _roleDelta = createHashMap;
            if (_towerDelta > 0) then
            {
                _roleDelta set ["tower_north",   _towerDelta];
                _roleDelta set ["tower_south",   _towerDelta];
                _roleDelta set ["tower_central", _towerDelta];
            };
            if (_reactionDelta > 0) then
            {
                _roleDelta set ["reaction", _reactionDelta];
            };
            _ctx set ["roleDelta", _roleDelta];

            diag_log format ["[ARC][SITEPOP][INFO] ARC_fnc_sitePopGetSpawnModifiers: '%1' PRISON_HARDENED adaptLevel=%2 guardCas=%3 towerDelta=%4 reactionDelta=%5.",
                _siteId, _adaptLevel, _guardCas, _towerDelta, _reactionDelta];
        };
    };

    case "PALACE_HARDENED":
    {
        // +1 guard per adaptation level (up to +2).
        private _guardDelta = (_adaptLevel min 2) max 0;
        if (_guardDelta > 0) then
        {
            private _roleDelta = createHashMap;
            _roleDelta set ["guard", _guardDelta];
            _ctx set ["roleDelta", _roleDelta];
        };
    };

    case "EMBASSY_HARDENED":
    {
        // Same as PALACE_HARDENED.
        private _guardDelta = (_adaptLevel min 2) max 0;
        if (_guardDelta > 0) then
        {
            private _roleDelta = createHashMap;
            _roleDelta set ["guard", _guardDelta];
            _ctx set ["roleDelta", _roleDelta];
        };
    };

    default { /* No modifiers for DEFAULT policy. */ };
};

_ctx
