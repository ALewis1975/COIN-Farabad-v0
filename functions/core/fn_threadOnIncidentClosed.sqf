/*
    Update an intel thread when a lead-driven incident closes.

    This is the core of the "Confidence vs Heat" model:
      - Confidence rises with reliable, specific evidence (and decays with age)
      - Heat rises with noisy operations and leaks (infiltration), pushing the commander to relocate/flee

    Params:
        0: STRING - threadId ("ARC_thr_#") ("" => no-op)
        1: STRING - result ("SUCCEEDED" / "FAILED" / ...)
        2: STRING - incidentType
        3: STRING - incidentTag (optional, e.g. "CMDNODE")
        4: STRING - zoneId (optional)
        5: ARRAY  - position [x,y,z] (optional)
        6: STRING - taskId (optional)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_threadId", ""],
    ["_result", ""],
    ["_incidentType", ""],
    ["_incidentTag", ""],
    ["_zone", ""],
    ["_pos", []],
    ["_taskId", ""]
];

if (_threadId isEqualTo "" || { _result isEqualTo "" }) exitWith {false};

private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then { _threads = []; };

private _idx = _threads findIf { _x isEqualType [] && { (count _x) >= 14 } && { (_x # 0) isEqualTo _threadId } };
if (_idx < 0) exitWith {false};

private _thr = _threads # _idx;

private _now = serverTime;

private _typeU = toUpper _incidentType;
private _resU  = toUpper _result;
private _tagU  = toUpper _incidentTag;

private _inf = ["infiltration", 0.35] call ARC_fnc_stateGet;
_inf = (_inf max 0) min 1;

private _conf = (_thr # 4) max 0 min 1;
private _heat = (_thr # 5) max 0 min 1;
private _state = _thr # 6;
private _evi = _thr # 7;
if (!(_evi isEqualType [])) then { _evi = []; };

// Mark touched
_thr set [10, _now];

// --- Heat: how "spooked" the cell is ----------------------------------------
private _heatDelta = switch (_typeU) do
{
    case "RAID":       { if (_resU isEqualTo "SUCCEEDED") then {0.18} else {0.26} };
    case "IED":        { if (_resU isEqualTo "SUCCEEDED") then {0.12} else {0.18} };
    case "RECON":      { if (_resU isEqualTo "SUCCEEDED") then {0.05} else {0.08} };
    case "PATROL":     { if (_resU isEqualTo "SUCCEEDED") then {0.04} else {0.06} };
    case "CIVIL":      { if (_resU isEqualTo "SUCCEEDED") then {0.04} else {0.07} };
    case "CHECKPOINT": { if (_resU isEqualTo "SUCCEEDED") then {0.10} else {0.14} };
    case "DEFEND":     { if (_resU isEqualTo "SUCCEEDED") then {0.16} else {0.22} };
    case "QRF":        { if (_resU isEqualTo "SUCCEEDED") then {0.16} else {0.22} };
    default             { if (_resU isEqualTo "SUCCEEDED") then {0.08} else {0.12} };
};

// Command nodes are inherently loud.
if (_typeU find "CMDNODE" == 0 || { _tagU isEqualTo "CMDNODE" }) then
{
    _heatDelta = _heatDelta + 0.18;
};

// Infiltration makes heat worse (leaks, tipped raids, disinfo storms).
_heatDelta = _heatDelta * (1 + (0.60 * _inf));

_heat = (_heat + _heatDelta) min 1;
_thr set [5, _heat];

// --- Evidence: only successful outcomes add actionable evidence ----------------
if (_resU isEqualTo "SUCCEEDED") then
{
    private _kind = "OBS";
    private _rel  = 0.55;
    private _spec = 0.30;

    switch (_typeU) do
    {
        case "RECON":  { _kind = "OBS";    _rel = 0.55; _spec = 0.35; };
        case "PATROL": { _kind = "OBS";    _rel = 0.50; _spec = 0.25; };
        case "CIVIL":  { _kind = "HUMINT"; _rel = 0.60; _spec = 0.25; };
        case "CHECKPOINT": { _kind = "SCREEN"; _rel = 0.55; _spec = 0.30; };
        case "IED":    { _kind = "TECHINT"; _rel = 0.65; _spec = 0.40; };
        case "RAID":   { _kind = "DOCS";   _rel = 0.70; _spec = 0.45; };
        default         { _kind = "MISC";   _rel = 0.55; _spec = 0.28; };
    };

    if (_typeU find "CMDNODE" == 0) then
    {
        _kind = "CAPTURE";
        _rel  = 0.85;
        _spec = 0.60;
    };

    _evi pushBack [_now, _rel, _spec, _kind, _taskId];

    // Cap evidence so persistence doesn't bloat.
    if ((count _evi) > 12) then
    {
        _evi deleteAt 0;
    };

    _thr set [7, _evi];
};

// Follow-up counts
private _suc = _thr # 8;
private _fail = _thr # 9;
if (_resU isEqualTo "SUCCEEDED") then { _suc = _suc + 1; };
if (_resU isEqualTo "FAILED") then { _fail = _fail + 1; };
_thr set [8, _suc];
_thr set [9, _fail];

// Recalc confidence now (thread tick will keep it honest over time)
private _eviTTL = 4 * 60 * 60;
private _score = 0;
{
    if (!(_x isEqualType []) || { (count _x) < 3 }) then { continue; };
    _x params ["_t", ["_rel", 0.5], ["_spec", 0.3]];
    private _age = (_now - _t) max 0;
    private _fresh = (1 - (_age / _eviTTL)) max 0;
    _score = _score + ((_rel max 0) min 1) * ((_spec max 0) min 1) * _fresh;
} forEach _evi;

_conf = 1 - (exp (-1.35 * _score));
_conf = (_conf max 0.05) min 1;

// Failure slightly shakes confidence (we thought we knew... maybe we didn't).
if (_resU isEqualTo "FAILED") then
{
    _conf = (_conf * 0.92) max 0.05;
};

_thr set [4, _conf];

// Commander state update based on effective heat
private _effHeat = (_heat + (0.15 * _inf)) min 1;
private _newState = switch (true) do
{
    case (_effHeat >= 0.90): {"EXFIL"};
    case (_effHeat >= 0.75): {"RELOCATING"};
    case (_effHeat >= 0.55): {"ALERTED"};
    default {"OPERATING"};
};

_thr set [6, _newState];

// If the commander is relocating/exfiling, shift the thread base (simulated displacement).
if (_newState in ["RELOCATING", "EXFIL"] && { _pos isEqualType [] && { (count _pos) >= 2 } }) then
{
    private _avoid = ["Airbase", "GreenZone"];
    private _newBase = [_pos, 2600, _avoid] call ARC_fnc_worldPickEnterablePosNear;
    if (_newBase isEqualType [] && { (count _newBase) >= 2 }) then
    {
        _thr set [3, _newBase];
    };
};

// --- Command node resolution effects ------------------------------------------
if (_typeU find "CMDNODE" == 0 || { _tagU isEqualTo "CMDNODE" }) then
{
    // Success: disrupt the cell.
    if (_resU isEqualTo "SUCCEEDED") then
    {
        _thr set [6, "DORMANT"];        // commander neutralized/disrupted
        _thr set [5, (_heat * 0.40)];   // heat drops sharply
        _thr set [4, 0.18];             // confidence resets (network is fragmented)
        _thr set [11, _now + (4 * 60 * 60)]; // long cooldown

        // Strategic impact: reduce pressure noticeably.
        private _p = ["insurgentPressure", 0.60] call ARC_fnc_stateGet;
        _p = (_p - 0.06) max 0;
        ["insurgentPressure", _p] call ARC_fnc_stateSet;
    }
    else
    {
        // Failure: the commander escapes and the thread becomes noisy and uncertain.
        _thr set [6, "EXFIL"];
        _thr set [5, (_heat + 0.10) min 1];
        _thr set [4, (_conf * 0.75) max 0.12];
        _thr set [11, _now + (2 * 60 * 60)];

        // Immediate follow-up lead: track fleeing commander
        private _avoid = ["Airbase", "GreenZone"];
        private _pPos = _pos;
        if (!(_pPos isEqualType []) || { (count _pPos) < 2 }) then
        {
            _pPos = _thr # 3;
        };

        private _trackPos = [_pPos, 2200, _avoid] call ARC_fnc_worldPickEnterablePosNear;
        ["RECON", "Lead: Track Fleeing Commander", _trackPos, 0.90, 35 * 60, _taskId, _incidentType, _threadId, ""] call ARC_fnc_leadCreate;
    };
};

// Persist thread record
_threads set [_idx, _thr];
["threads", _threads] call ARC_fnc_stateSet;

// Opportunity: maybe create a command node lead (only after normal follow-ups)
if (_resU isEqualTo "SUCCEEDED" && { !(_typeU find "CMDNODE" == 0) }) then
{
    [_threadId] call ARC_fnc_threadMaybeCreateCommandNodeLead;
};

[] call ARC_fnc_threadBroadcast;
true
