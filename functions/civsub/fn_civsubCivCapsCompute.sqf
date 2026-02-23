/*
    ARC_fnc_civsubCivCapsCompute

    Params:
      0: activeDistrictIds (array)

    Returns: [capGlobalEff, capPerDistrictEff]
*/

if (!isServer) exitWith {[0,0]};

params [
    ["_active", [], [[]]]
];

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _capG = missionNamespace getVariable ["civsub_v1_civ_cap_global", 24];
private _capD = missionNamespace getVariable ["civsub_v1_civ_cap_perDistrict", 8];

private _ov = missionNamespace getVariable ["civsub_v1_civ_cap_overrides", []];
if (isNil "_ov") then { _ov = []; };
if !(_ov isEqualType []) then { _ov = []; };
private _ovMap = createHashMap;
{
    _x params [["_did","",[""]], ["_cap", -1, [0]]];
    if (_did != "" && { _cap >= 0 }) then { _ovMap set [_did, _cap]; };
} forEach _ov;
missionNamespace setVariable ["civsub_v1_civ_cap_overrides_map", _ovMap, true];

// Log overrides only when they change (to avoid RPT spam)
if (missionNamespace getVariable ["civsub_v1_debug", false]) then {
    private _k = str _ov;
    private _k0 = missionNamespace getVariable ["civsub_v1_civ_cap_overrides_key", ""];
    if (_k != _k0) then {
        missionNamespace setVariable ["civsub_v1_civ_cap_overrides_key", _k, true];
        diag_log format ["[CIVSUB][CIVS] cap overrides updated: %1", _ov];
    };
};

if (!(_capG isEqualType 0)) then { _capG = 24; };
if (!(_capD isEqualType 0)) then { _capD = 8; };

if (_capG < 0) then { _capG = 0; };
if (_capD < 0) then { _capD = 0; };

private _n = count _active;
private _capGE = _capG;
private _capDE = _capD;

// Dynamic per-district caps (scale by district population + civilian alive state)
private _capByD = createHashMap;

private _useDynamic = missionNamespace getVariable ["civsub_v1_civ_cap_dynamic", true];
if !(_useDynamic isEqualType true) then { _useDynamic = true; };

private _minD = missionNamespace getVariable ["civsub_v1_civ_cap_minPerDistrict", 1];
if !(_minD isEqualType 0) then { _minD = 1; };
if (_minD < 0) then { _minD = 0; };

// Reference population for scaling (defaults to max district pop_total)
private _popRef = missionNamespace getVariable ["civsub_v1_civ_cap_popRef", -1];
if !(_popRef isEqualType 0) then { _popRef = -1; };

private _districtsAll = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districtsAll isEqualType createHashMap) then { _districtsAll = createHashMap; };

if (_popRef <= 0) then {
    private _mx = 1;
    {
        private _d0 = _districtsAll getOrDefault [_x, createHashMap];
        if (_d0 isEqualType []) then { _d0 = [_d0] call _hmCreate; };
        if (_d0 isEqualType createHashMap) then {
            private _p0 = _d0 getOrDefault ["pop_total", 0];
            if (_p0 isEqualType 0) then { _mx = _mx max _p0; };
        };
    } forEach (keys _districtsAll);
    _popRef = _mx max 1;
    // Keep local (no need to spam PV); this is just a scaling reference.
    missionNamespace setVariable ["civsub_v1_civ_cap_popRef", _popRef, false];
};

private _sumCaps = 0;

{
    private _did = _x;
    private _capThis = _capD;

    if (_useDynamic) then {
        private _ds = _districtsAll getOrDefault [_did, createHashMap];
        if (_ds isEqualType []) then { _ds = [_ds] call _hmCreate; };

        if (_ds isEqualType createHashMap) then {
            private _pop = _ds getOrDefault ["pop_total", 0];
            if !(_pop isEqualType 0) then { _pop = 0; };
            if (_pop < 0) then { _pop = 0; };

            private _kia = _ds getOrDefault ["civ_cas_kia", 0];
            if !(_kia isEqualType 0) then { _kia = 0; };
            if (_kia < 0) then { _kia = 0; };

            if (_pop <= 0) then {
                _capThis = 0;
            } else {
                // Scale linearly from capD at popRef
                private _base = round (_capD * (_pop / _popRef));
                if (_base < _minD) then { _base = _minD; };
                if (_base > _capD) then { _base = _capD; };

                // Reduce by virtual alive ratio
                private _alive = (_pop - _kia) max 0;
                if (_alive <= 0) then {
                    _capThis = 0;
                } else {
                    private _ratio = _alive / _pop;
                    _capThis = round (_base * _ratio);
                    if (_capThis < _minD) then { _capThis = _minD; };
                };
            };
        };
    };

    // Explicit overrides always win.
    private _ovCap = _ovMap getOrDefault [_did, -1];
    if (_ovCap isEqualType 0 && { _ovCap >= 0 }) then { _capThis = _ovCap; };

    if (_capThis < 0) then { _capThis = 0; };
    _capByD set [_did, _capThis];
    _sumCaps = _sumCaps + _capThis;
} forEach _active;

// Global cap is bounded by the sum of effective district caps.
if (_sumCaps < _capGE) then { _capGE = _sumCaps; };
if (_capGE < 0) then { _capGE = 0; };

missionNamespace setVariable ["civsub_v1_civ_cap_effectiveGlobal", _capGE, true];
missionNamespace setVariable ["civsub_v1_civ_cap_effectivePerDistrict", _capDE, true];
missionNamespace setVariable ["civsub_v1_civ_cap_effectiveByDistrict", _capByD, true];

// Optional debug
if (missionNamespace getVariable ["civsub_v1_debug", false]) then {
    private _k = str _capByD;
    private _k0 = missionNamespace getVariable ["civsub_v1_civ_cap_effectiveByDistrict_key", ""];
    if (_k != _k0) then {
        missionNamespace setVariable ["civsub_v1_civ_cap_effectiveByDistrict_key", _k, true];
        diag_log format ["[CIVSUB][CIVS] capByDistrict=%1 capGE=%2 capDMax=%3 popRef=%4 nActive=%5", _capByD, _capGE, _capD, _popRef, _n];
    };
};

[_capGE, _capDE]