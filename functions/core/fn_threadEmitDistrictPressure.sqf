/*
    Aggregate active thread pressure at district level via CIVSUB deltas.

    Converts thread confidence/heat into bounded district INTIMIDATION_EVENT
    emissions so all district state mutation stays on ARC_fnc_civsubEmitDelta.

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {false};

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; [(_h), _k, _d] call _hg";
private _keysFn   = compile "params ['_m']; keys _m";

private _threads = ["threads", []] call ARC_fnc_stateGet;
if !(_threads isEqualType []) exitWith {false};

private _agg = createHashMap;

{
    private _thr = [_x] call ARC_fnc_threadNormalizeRecord;
    if (_thr isEqualTo []) then { continue; };

    private _did = _thr select 14;
    if (_did isEqualTo "") then { continue; };

    private _state = toUpper (_thr select 6);
    if (_state isEqualTo "DORMANT") then { continue; };

    private _conf = (_thr select 4) max 0 min 1;
    private _heat = (_thr select 5) max 0 min 1;

    // Pressure only when there is meaningful active pursuit signal.
    private _p = ((_conf * 0.60) + (_heat * 0.90) - 0.35) max 0;
    if (_p <= 0) then { continue; };

    _agg set [_did, ([_agg, _did, 0] call _hg) + _p];

} forEach _threads;

{
    private _did = _x;
    private _score = [_agg, _did, 0] call _hg;

    // Convert to bounded integer pulses so deltas remain modest and predictable.
    private _pulses = floor (_score min 3);
    if (_pulses <= 0) then { continue; };

    for "_i" from 1 to _pulses do
    {
        [_did, "INTIMIDATION_EVENT", "THREADS", createHashMap] call ARC_fnc_civsubEmitDelta;
    };

} forEach ([_agg] call _keysFn);

true
