/*
    ARC_fnc_worldSpawnRoleResolve

    Server: resolve a symbolic spawn-pattern role tag + side into a validated
    pool of concrete CfgVehicles classnames for the transient overlay spawner
    (issue #633 step 4). Mirrors the faction-enumeration approach used by
    data/farabad_site_templates.sqf and ARC_fnc_opsSpawnLocalSupport so pools
    stay correct against the live mod preset (3CB classnames are abbreviated,
    e.g. UK3CB_TKP_B_AR — never the *_Soldier names) and invalid classes are
    filtered out, preventing missing-class RPT spam.

    Pools are enumerated once and memoised in ARC_worldSpawnRoleCache keyed by
    "side|roleTag". An empty resolved pool logs a one-shot WARN (diagnostics,
    issue #633 step 9) so operators can spot mod-preset mismatches before the
    overlay toggle is enabled.

    Params:
        0: STRING — sideStr ("west" | "east" | "indep" | "civ").
        1: STRING — roleTag (symbolic, e.g. "vendor", "gate_guard", "hostile").

    Returns: ARRAY — validated CfgVehicles classnames (possibly empty).
*/

if (!isServer) exitWith {[]};

params [
    ["_sideStr", "civ", [""]],
    ["_roleTag", "unit", [""]]
];

private _sideL = toLower _sideStr;
private _roleL = toLower _roleTag;

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _cacheKey = format ["%1|%2", _sideL, _roleL];
private _cache = missionNamespace getVariable ["ARC_worldSpawnRoleCache", createHashMap];
if (!(_cache isEqualType createHashMap)) then { _cache = createHashMap; };
if (([_cache, _cacheKey, false] call _hg) isEqualType []) exitWith {
    [_cache, _cacheKey, []] call _hg
};

// --- Faction base pools (memoised across calls) --------------------------
private _basePools = missionNamespace getVariable ["ARC_worldSpawnBasePools", createHashMap];
if (!(_basePools isEqualType createHashMap) || { !([_basePools, "built", false] call _hg) }) then {
    _basePools = createHashMap;

    // Enumerate 3CB host-nation police (TKP, west) and army (TKA, west) +
    // OPFOR insurgents (MEI/MEE, east) + civilians (side 3) from CfgVehicles.
    private _tkp = [];
    private _tka = [];
    private _opfor = [];
    private _civ = [];
    private _worker = [];
    {
        if (getNumber (_x >> "scope") != 2) then { continue; };
        private _cn = configName _x;
        if !(_cn isKindOf "Man") then { continue; };
        private _sideN = getNumber (_x >> "side");
        private _fac = getText (_x >> "faction");
        switch (true) do {
            case (_sideN == 1 && { _fac isEqualTo "UK3CB_TKP_B" }): { _tkp pushBack _cn; };
            case (_sideN == 1 && { _fac isEqualTo "UK3CB_TKA_B" }): { _tka pushBack _cn; };
            case (_sideN == 0 && { _fac isEqualTo "UK3CB_MEI_O" }): { _opfor pushBack _cn; };
            case (_sideN == 0 && { _fac isEqualTo "UK3CB_MEE_O" }): { _opfor pushBack _cn; };
            case (_sideN == 3 && { (_fac select [0, 5]) isEqualTo "UK3CB" }): {
                if (((toLower _cn) find "labour") >= 0 || { ((toLower _cn) find "worker") >= 0 }) then {
                    _worker pushBack _cn;
                } else {
                    _civ pushBack _cn;
                };
            };
        };
    } forEach ("true" configClasses (configFile >> "CfgVehicles"));

    // Fallbacks (graceful when the faction mod is absent). These mirror the
    // curated lists in initServer.sqf / farabad_site_templates.sqf.
    if ((count _tkp) == 0) then { _tkp = ["UK3CB_TKP_B_TL","UK3CB_TKP_B_SL","UK3CB_TKP_B_RIF_1","UK3CB_TKP_B_AR","UK3CB_TKP_B_OFF"]; };
    if ((count _tka) == 0) then { _tka = ["UK3CB_TKA_B_AR","UK3CB_TKA_B_TL","UK3CB_TKA_B_OFF"]; };
    if ((count _opfor) == 0) then {
        _opfor = missionNamespace getVariable ["ARC_opforPatrolUnitClasses", []];
        if (!(_opfor isEqualType []) || { (count _opfor) == 0 }) then {
            _opfor = ["O_G_Soldier_F","O_G_Soldier_GL_F","O_G_Soldier_AR_F","O_G_Soldier_TL_F"];
        };
    };
    if ((count _civ) == 0) then {
        _civ = missionNamespace getVariable ["civsub_v1_civ_classPool", ["C_man_1"]];
        if (!(_civ isEqualType []) || { (count _civ) == 0 }) then { _civ = ["C_man_1"]; };
    };
    if ((count _worker) == 0) then { _worker = _civ; };

    private _civMed = ["UK3CB_MEC_C_DOC","UK3CB_TKC_C_DOC","UK3CB_CHC_C_DOC","C_IDAP_Man_Paramedic_01_F"];
    private _staff  = ["UK3CB_MEC_C_FUNC","UK3CB_CHC_C_FUNC","UK3CB_CHC_C_POLITIC","UK3CB_ADC_C_FUNC","C_Story_Scientist_01_F"];

    _basePools set ["tkp", _tkp];
    _basePools set ["tka", _tka];
    _basePools set ["opfor", _opfor];
    _basePools set ["civ", _civ];
    _basePools set ["worker", _worker];
    _basePools set ["civmed", _civMed];
    _basePools set ["staff", _staff];
    _basePools set ["built", true];
    missionNamespace setVariable ["ARC_worldSpawnBasePools", _basePools];
};

// --- Role tag -> base-pool category --------------------------------------
private _isMedical    = (_roleL find "doctor" >= 0) || { _roleL find "nurse" >= 0 } || { _roleL find "medic" >= 0 } || { _roleL find "paramedic" >= 0 } || { _roleL isEqualTo "civ_doctor" };
private _isWorker     = (_roleL find "worker" >= 0) || { _roleL find "contractor" >= 0 } || { _roleL find "technician" >= 0 } || { _roleL find "stevedore" >= 0 } || { _roleL find "mechanic" >= 0 } || { _roleL find "crew" >= 0 } || { _roleL find "labour" >= 0 };
private _isStaff      = (_roleL find "gov_staff" >= 0) || { _roleL find "official" >= 0 } || { _roleL find "staff" >= 0 };

private _pool = [];
switch (_sideL) do {
    case "east": { _pool = [_basePools, "opfor", []] call _hg; };
    case "civ": {
        switch (true) do {
            case _isMedical: { _pool = [_basePools, "civmed", []] call _hg; };
            case _isWorker:  { _pool = [_basePools, "worker", []] call _hg; };
            default          { _pool = [_basePools, "civ", []] call _hg; };
        };
    };
    case "indep": { _pool = [_basePools, "tka", []] call _hg; };
    default /* west */ {
        switch (true) do {
            case _isMedical: {
                private _tkp = [_basePools, "tkp", []] call _hg;
                private _meds = _tkp select { ((toLower _x) find "medic") >= 0 || { ((toLower _x) find "_md") >= 0 } || { ((toLower _x) find "doc") >= 0 } };
                _pool = if ((count _meds) > 0) then { _meds } else { _tkp };
            };
            case _isStaff:   { _pool = [_basePools, "staff", []] call _hg; };
            default          { _pool = [_basePools, "tkp", []] call _hg; };
        };
    };
};

// --- Validate against CfgVehicles (memoised existence check) -------------
private _valid = [];
{
    if ([_x] call ARC_fnc_cfgClassExists) then { _valid pushBackUnique _x; };
} forEach _pool;

if ((count _valid) == 0) then {
    private _warned = missionNamespace getVariable ["ARC_worldSpawnRoleWarned", []];
    if (!(_warned isEqualType [])) then { _warned = []; };
    if (!(_cacheKey in _warned)) then {
        _warned pushBack _cacheKey;
        missionNamespace setVariable ["ARC_worldSpawnRoleWarned", _warned];
        diag_log format ["[ARC][SPAWNPAT][WARN] ARC_fnc_worldSpawnRoleResolve: role '%1' side '%2' resolved to an EMPTY class pool against the live mod preset; overlay role skipped.", _roleTag, _sideStr];
    };
};

_cache set [_cacheKey, _valid];
missionNamespace setVariable ["ARC_worldSpawnRoleCache", _cache];

_valid
