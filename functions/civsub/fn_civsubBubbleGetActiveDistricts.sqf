/*
    ARC_fnc_civsubBubbleGetActiveDistricts

    Params:
      0: players (array of objects)

    Returns: array of district IDs, capped by civsub_v1_civ_cap_activeDistrictsMax

    Hotfix08 (Active district hysteresis):
      - Prevents rapid district flips when players stand near district borders.
      - A district remains "active" for a grace period after the last player was seen inside it.
      - Default grace is controlled by civsub_v1_activeDistrict_grace_s (seconds).
*/

if (!isServer) exitWith {[]};

params [
    ["_players", [], [[]]]
];


// sqflint-compatible helpers
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _maxD = missionNamespace getVariable ["civsub_v1_civ_cap_activeDistrictsMax", 3];
if (!(_maxD isEqualType 0)) then { _maxD = 3; };
if (_maxD < 1) then { _maxD = 1; };

private _now = serverTime;
private _grace = missionNamespace getVariable ["civsub_v1_activeDistrict_grace_s", 180];
if (!(_grace isEqualType 0)) then { _grace = 180; };
if (_grace < 0) then { _grace = 0; };

// Track last seen per district (server-local; no need to publicVariable)
private _last = missionNamespace getVariable ["civsub_v1_activeDistrictLastSeen", createHashMap];
if !(_last isEqualType createHashMap) then { _last = createHashMap; };

// Update last-seen for districts containing current players
{
    private _did = [getPosATL _x] call ARC_fnc_civsubDistrictsFindByPos;
    if !(_did isEqualTo "") then {
        _last set [_did, _now];
    };
} forEach _players;

// Compute active districts as those seen within grace window
private _active = [];
{
    private _did = _x;
    private _ts = [_last, _did, -1] call _hg;
    if (_ts >= 0 && {(_now - _ts) <= _grace}) then {
        _active pushBack _did;
    };
} forEach (keys _last);

// Stable sort by ID (D01..)
_active sort true;

if ((count _active) > _maxD) then {
    _active resize _maxD;
};

missionNamespace setVariable ["civsub_v1_activeDistrictLastSeen", _last];

_active
