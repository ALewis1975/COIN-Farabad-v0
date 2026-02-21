/*
    ARC_fnc_civsubCivCleanupTick

    Cleans registry and despawns civs that are null or outside active districts.
    Hotfix02 (KeepBodies): dead civ bodies remain in-world; we only remove them from the active registry.
    Processes a bounded number of despawns per tick.
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_civs_enabled", false]) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _mapGet   = compile "params ['_h','_k']; _h get _k";
private _keysFn   = compile "params ['_m']; keys _m";

private _reg = missionNamespace getVariable ["civsub_v1_civ_registry", createHashMap];
if !(_reg isEqualType createHashMap) then { _reg = createHashMap; };

private _active = missionNamespace getVariable ["civsub_v1_activeDistrictIds", []];
if !(_active isEqualType []) then { _active = []; };

private _q = missionNamespace getVariable ["civsub_v1_civ_despawnQueue", []];
if !(_q isEqualType []) then { _q = []; };

// Scan registry for invalid or out-of-scope
{
    private _k = _x;
    private _row = [_reg, _k] call _mapGet;
    if !(_row isEqualType createHashMap) then {
        _reg deleteAt _k;
    } else {
        private _u = [_row, "unit", objNull] call _hg;
        private _did = [_row, "districtId", ""] call _hg; 

        if (isNull _u) then {
            _reg deleteAt _k;
        } else {
            if (!alive _u) then {
                // Keep body in-world; remove from active registry (caps). Tag for future morgue automation.
                _u setVariable ["civsub_v1_dead", true, true];
                _u setVariable ["civsub_v1_dead_ts", serverTime, true];
                _u setVariable ["civsub_v1_dead_districtId", _did, true];
                _reg deleteAt _k;
            } else {
                // If district is no longer active, queue for despawn (living only)
                if (!(_did in _active)) then {
                    if (!([_u] call ARC_fnc_civsubCivIsProtected)) then {
                        _q pushBackUnique _k;
                    };
                };
            };
        };
    };
} forEach ([_reg] call _keysFn);

// Process a bounded number per tick to avoid spikes
private _max = 6;
private _n = count _q;
if (_n > 0) then
{
    private _take = _max;
    if (_n < _take) then { _take = _n; };

    for "_i" from 0 to (_take - 1) do
    {
        private _k = _q deleteAt 0;
        private _row = [_reg, _k, createHashMap] call _hg;
        if (_row isEqualType createHashMap) then {
            private _u = [_row, "unit", objNull] call _hg;
            if (!isNull _u) then {
                [_u] call ARC_fnc_civsubCivDespawnUnit;
            };
        };
        _reg deleteAt _k;
    };
};

missionNamespace setVariable ["civsub_v1_civ_registry", _reg, true];
missionNamespace setVariable ["civsub_v1_civ_despawnQueue", _q, true];
missionNamespace setVariable ["civsub_v1_civ_cleanup_last_ts", serverTime, true];

true
