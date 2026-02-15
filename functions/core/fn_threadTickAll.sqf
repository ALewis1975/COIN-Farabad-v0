/*
    Server: periodic thread maintenance.

    - Decays heat over time
    - Prunes stale evidence and recalculates confidence
    - Updates commander state based on heat/infiltration

    Intended to be called from ARC_fnc_incidentTick (every ~60s).

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then { _threads = []; };

if (_threads isEqualTo []) exitWith
{
    // Still publish an empty view so TOC tools don't show stale data.
    [] call ARC_fnc_threadBroadcast;
    true
};

private _now = serverTime;

// Global infiltration makes leaks more likely; heat is "stickier".
private _inf = ["infiltration", 0.35] call ARC_fnc_stateGet;
_inf = (_inf max 0) min 1;

// Evidence TTL (seconds): after this, it no longer contributes.
private _eviTTL = 4 * 60 * 60;

private _changed = false;

{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 14) then { continue; };

    private _id     = _x # 0;
    private _type   = _x # 1;
    private _zone   = _x # 2;
    private _base   = _x # 3;
    private _conf   = (_x # 4) max 0 min 1;
    private _heat   = (_x # 5) max 0 min 1;
    private _state  = _x # 6;
    private _evi    = _x # 7;
    private _touch  = _x # 10;

    if (!(_evi isEqualType [])) then { _evi = []; };

    // Heat decay: slows down as infiltration rises.
    private _decay = 0.0025 * (1 - (0.45 * _inf)); // ~0.15/hour at inf=0
    if ((_now - _touch) > (45 * 60)) then { _decay = _decay * 1.35; }; // stale pursuit cools off faster

    private _newHeat = (_heat - _decay) max 0;

    // Prune old evidence
    private _newEvi = [];
    {
        if (!(_x isEqualType []) || { (count _x) < 5 }) then { continue; };
        private _t = _x # 0;
        if (!(_t isEqualType 0)) then { continue; };
        if ((_now - _t) <= _eviTTL) then
        {
            _newEvi pushBack _x;
        };
    } forEach _evi;

    // Recalc confidence from remaining evidence
    private _score = 0;
    {
        _x params ["_t", ["_rel", 0.5], ["_spec", 0.3]];
        private _age = (_now - _t) max 0;
        private _fresh = (1 - (_age / _eviTTL)) max 0;
        _score = _score + ((_rel max 0) min 1) * ((_spec max 0) min 1) * _fresh;
    } forEach _newEvi;

    private _newConf = 1 - (exp (-1.35 * _score));
    _newConf = (_newConf max 0.05) min 1;

    // Commander state update
    private _effHeat = (_newHeat + (0.15 * _inf)) min 1;

    private _newState = switch (true) do
    {
        case (_effHeat >= 0.90): {"EXFIL"};
        case (_effHeat >= 0.75): {"RELOCATING"};
        case (_effHeat >= 0.55): {"ALERTED"};
        default {"OPERATING"};
    };

    // If we haven't touched this thread in a long time, it becomes dormant.
    if ((_now - _touch) > (120 * 60) && { _newHeat < 0.15 } && { _newConf < 0.25 }) then
    {
        _newState = "DORMANT";
    };

    if (_newHeat != _heat || { _newConf != _conf } || { _newState != _state } || { !(_newEvi isEqualTo _evi) }) then
    {
        _x set [4, _newConf];
        _x set [5, _newHeat];
        _x set [6, _newState];
        _x set [7, _newEvi];
        _threads set [_forEachIndex, _x];
        _changed = true;
    };

} forEach _threads;

if (_changed) then
{
    ["threads", _threads] call ARC_fnc_stateSet;
};

[] call ARC_fnc_threadBroadcast;
true
