/*
    ARC_fnc_threatSchedulerTick

    Threat Economy v0: rate-limited scheduler tick (call from bootstrapServer regular tick).
    Does NOT spawn anything — calls ARC_fnc_threatScheduleEvent per cleared district.

    Rate: controlled by ARC_threatSchedulerIntervalS (default 120s).

    Returns:
      BOOL (false = not fired this tick)
*/

if (!isServer) exitWith {false};

private _intervalS = missionNamespace getVariable ["ARC_threatSchedulerIntervalS", 120];
if (!(_intervalS isEqualType 0) || { _intervalS < 30 }) then { _intervalS = 120; };

private _lastTs = ["threat_v0_scheduler_last_ts", -1] call ARC_fnc_stateGet;
if (!(_lastTs isEqualType 0)) then { _lastTs = -1; };

private _now = serverTime;
if (_lastTs > 0 && { (_now - _lastTs) < _intervalS }) exitWith {false};

["threat_v0_scheduler_last_ts", _now] call ARC_fnc_stateSet;

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _districtIds = [
    "D01","D02","D03","D04","D05","D06","D07","D08","D09","D10",
    "D11","D12","D13","D14","D15","D16","D17","D18","D19","D20"
];

// Build open threat district index (quick look-up to skip already-open districts)
private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
if (!(_records isEqualType [])) then { _records = []; };

private _openDistricts = [];
{
    private _rec = _x;
    private _stateU = toUpper ((_rec select {(_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "state"}} select [0,1]) apply {_x select 1} select [0,""] select 0);
    // Simplified: look for state not in terminal set
    private _stateVal = "";
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo "state") }) exitWith { _stateVal = _x select 1; };
    } forEach _rec;
    _stateVal = toUpper _stateVal;

    if (!(_stateVal in ["CLOSED","CLEANED","EXPIRED"])) then
    {
        private _links = [];
        { if ((_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "links"}) exitWith { _links = _x select 1; }; } forEach _rec;
        private _dId = "";
        { if ((_x isEqualType []) && {(count _x) >= 2} && {(_x select 0) isEqualTo "district_id"}) exitWith { _dId = _x select 1; }; } forEach _links;
        if (!(_dId isEqualTo "")) then { _openDistricts pushBackUnique _dId; };
    };
} forEach _records;

// Determine current escalation tier from AO posture
private _scheduledAny = false;

{
    private _districtId = _x;

    // Skip if already has an open threat
    if (_districtId in _openDistricts) then { continue; };

    // Read posture for tier
    private _secLevel = missionNamespace getVariable [format ["ARC_district_%1_secLevel", _districtId], "NORMAL"];
    private _tier = 0;
    if (_secLevel isEqualTo "ELEVATED") then { _tier = 1; };
    if (_secLevel isEqualTo "HIGH_RISK") then { _tier = 2; };

    private _govResult = [_districtId, "IED", _tier] call ARC_fnc_threatGovernorCheck;
    private _allowed   = _govResult select 0;

    if (_allowed) then
    {
        [_districtId, _tier] call ARC_fnc_threatScheduleEvent;
        _scheduledAny = true;
    };
} forEach _districtIds;

_scheduledAny
