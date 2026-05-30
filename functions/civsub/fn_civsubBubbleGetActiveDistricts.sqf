/*
    ARC_fnc_civsubBubbleGetActiveDistricts

    Params:
      0: players (array of objects)

    Returns: array of district IDs, capped by civsub_v1_civ_cap_activeDistrictsMax

    Hotfix08 (Active district hysteresis):
      - Prevents rapid district flips when players stand near district borders.
      - A district remains "active" for a grace period after the last player was seen inside it.
      - Default grace is controlled by civsub_v1_activeDistrict_grace_s (seconds).

    Hotfix11 (Recency-priority cap):
      - When more districts are within the grace window than the active cap allows,
        keep the most-recently-seen districts (where players are now) instead of the
        lowest-ID ones. Prevents civs spawning far from players and active-set churn
        (despawn/respawn flicker) as players move across the map's 20 districts.
*/

if (!isServer) exitWith {[]};

params [
    ["_players", [], [[]]]
];

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

// Compute active districts as those seen within grace window.
// Pair each candidate with its age (now - lastSeen) so we can prioritise the
// districts players currently/most-recently occupy.
private _cand = [];
{
    private _did = _x;
    private _ts = _last getOrDefault [_did, -1];
    if (_ts >= 0 && {(_now - _ts) <= _grace}) then {
        _cand pushBack [(_now - _ts), _did];
    };
} forEach (keys _last);

// Prioritise by recency so the cap never evicts a player's own district (age ~0)
// in favour of stale lower-ID districts. Sort by age ascending (most recent
// first); ties (e.g. districts occupied this tick) break by ID ascending for a
// stable, deterministic result.
_cand sort true;

private _active = [];
{
    _active pushBack (_x select 1);
} forEach _cand;

if ((count _active) > _maxD) then {
    _active resize _maxD;
};

missionNamespace setVariable ["civsub_v1_activeDistrictLastSeen", _last];

_active
