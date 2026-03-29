/*
    Decide whether a Command Node opportunity should surface for a thread.

    A command node should be rare and require multiple converging factors:
      - high confidence (multiple fresh evidence points)
      - enough successful follow-ups to show the cell is being "worked"
      - the commander must still be vulnerable (heat not too extreme)
      - cooldown so we don't spam HVT events

    When heat is high, the commander doesn't sit still: the opportunity shifts into an intercept/chase.

    Params:
        0: STRING - threadId

    Returns:
      BOOL - true if created
*/

if (!isServer) exitWith {false};

params [["_threadId", ""]];
if (_threadId isEqualTo "") exitWith {false};

private _threads = ["threads", []] call ARC_fnc_stateGet;
if (!(_threads isEqualType [])) then { _threads = []; };

private _idx = -1;
{ if (([_x] call ARC_fnc_threadNormalizeRecord) isNotEqualTo [] && { ((_x # 0) isEqualTo _threadId) }) exitWith { _idx = _forEachIndex; }; } forEach _threads;
if (_idx < 0) exitWith {false};

private _thr = [(_threads # _idx)] call ARC_fnc_threadNormalizeRecord;

private _now = serverTime;

private _threadType = toUpper (_thr # 1);
private _zoneBias = _thr # 2;
private _basePos = _thr # 3;
private _conf = (_thr # 4) max 0 min 1;
private _heat = (_thr # 5) max 0 min 1;
private _state = toUpper (_thr # 6);
private _evi = _thr # 7;
private _fuSuccess = _thr # 8;
private _lastTouched = _thr # 10;
private _cooldownUntil = _thr # 11;
private _lastCmd = _thr # 12;

if (!(_evi isEqualType [])) then { _evi = []; };

// Only certain threads can generate command nodes.
if !(_threadType in ["IED_CELL", "INSIDER_NETWORK", "SMUGGLING_RING"]) exitWith {false};

// Pursuit has to be "active".
if ((_now - _lastTouched) > (75 * 60)) exitWith {false};

// Cooldown: prevent spam.
if (_cooldownUntil isEqualType 0 && { _cooldownUntil > 0 } && { _now < _cooldownUntil }) exitWith {false};
if (_lastCmd isEqualType 0 && { _lastCmd > 0 } && { (_now - _lastCmd) < (35 * 60) }) exitWith {false};

// Evidence requirements.
private _eCount = count _evi;
private _kinds = [];
{
    if (_x isEqualType [] && { (count _x) >= 4 }) then
    {
        _kinds pushBackUnique (_x # 3);
    };
} forEach _evi;

private _kindCount = count _kinds;

if (_fuSuccess < 3) exitWith {false};
if (_eCount < 3) exitWith {false};
if (_kindCount < 2) exitWith {false};
if (_conf < 0.78) exitWith {false};

// Global world state influences opportunity.
private _p = ["insurgentPressure", 0.60] call ARC_fnc_stateGet;
private _inf = ["infiltration", 0.35] call ARC_fnc_stateGet;
_p = (_p max 0) min 1;
_inf = (_inf max 0) min 1;

// Base chance is intentionally conservative.
private _chance = 0.08;
_chance = _chance + (0.24 * ((_conf - 0.78) / 0.22));
_chance = _chance + (0.05 * ((_fuSuccess - 3) min 3));
_chance = _chance - (0.10 * _heat);
_chance = _chance * (0.85 + (0.20 * _p));
_chance = _chance * (1 - (0.25 * _inf));

_chance = (_chance max 0.05) min 0.45;

if ((random 1) > _chance) exitWith {false};

// Do not create a second command node lead if one already exists for this thread.
private _leadPool = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leadPool isEqualType [])) then { _leadPool = []; };
private _hasCmd = -1;
{ if (_x isEqualType [] && { (count _x) >= 10 } && { (_x # 9) isEqualTo _threadId } && { toUpper (_x # 1) find "CMDNODE" == 0 }) exitWith { _hasCmd = _forEachIndex; }; } forEach _leadPool;
if (_hasCmd >= 0) exitWith {false};

// Variant: heat + commander state determine whether this is a raid, meet, or intercept.
private _variant = "CMDNODE_MEET";

if (_state isEqualTo "OPERATING" && { _heat < 0.45 }) then { _variant = "CMDNODE_RAID"; };
if (_state in ["RELOCATING", "EXFIL"] || { _heat >= 0.75 }) then { _variant = "CMDNODE_INTERCEPT"; };

// Extreme heat: commander goes dark and leaves a dead drop instead of a clean opportunity.
if (_heat >= 0.92) then
{
    _variant = "CMDNODE_INTERCEPT";
};

private _avoidZones = ["Airbase", "GreenZone"];

// Pick a reasonable position near the thread base.
private _radius = switch (_variant) do
{
    case "CMDNODE_RAID": { 1200 };
    case "CMDNODE_INTERCEPT": { 2200 };
    default { 1600 };
};

private _pos = _basePos;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
{
    _pos = [0,0,0];
};

_pos = [_pos, _radius, _avoidZones] call ARC_fnc_worldPickEnterablePosNear;

private _threadName = switch (_threadType) do
{
    case "IED_CELL": {"IED Cell Commander"};
    case "INSIDER_NETWORK": {"Insider Network Handler"};
    case "SMUGGLING_RING": {"Smuggling Ring Boss"};
    default {"OPFOR Commander"};
};

private _disp = switch (_variant) do
{
    case "CMDNODE_RAID": { format ["COMMAND NODE: %1 Safehouse", _threadName] };
    case "CMDNODE_INTERCEPT": { format ["COMMAND NODE: Intercept %1", _threadName] };
    default { format ["COMMAND NODE: %1 Meeting", _threadName] };
};

private _ttl = switch (_variant) do
{
    case "CMDNODE_INTERCEPT": { 25 * 60 };
    default { 35 * 60 };
};

// Create a high-priority lead. Strength 1.0 so it wins weighted selection.
[ _variant, _disp, _pos, 1.0, _ttl, "", "", _threadId, "CMDNODE" ] call ARC_fnc_leadCreate;

// Update cooldown and mark that the cell is now highly alert.
_thr set [11, _now + (90 * 60)];
_thr set [12, _now];
_thr set [6, "ALERTED"];

_threads set [_idx, _thr];
["threads", _threads] call ARC_fnc_stateSet;

[] call ARC_fnc_threadBroadcast;
true
