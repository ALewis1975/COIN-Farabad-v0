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

    Hotfix12 (Stationary presence buffer):
      - Refresh last-seen for every district within radius_m + 200 of a player
        to match the locked v1 ARC_fnc_civsubIsDistrictActive definition. Without this,
        stationary player just outside a (often small) district radius never
        refreshed last-seen, so the district expired after the grace window and its
        civilians despawned even though the player had not moved.
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

// Compiled HashMap helpers (sqflint parser-compat: avoid bare method-style
// getOrDefault / keys, matching the SQFLINT_COMPAT_GUIDE convention).
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _keysFn = compile "params ['_m']; keys _m";

// Update last-seen for districts within the activation buffer of any player.
// Matches the locked v1 activation definition in ARC_fnc_civsubIsDistrictActive
// (dist <= radius_m + 200). Using a buffered scan here (rather than strict
// centroid+radius containment via FindByPos) prevents civilians despawning when
// a stationary player sits just outside a — often small — district radius: their
// presence keeps refreshing last-seen so the grace window never expires.
private _buffer = missionNamespace getVariable ["civsub_v1_activeDistrict_buffer_m", 200];
if (!(_buffer isEqualType 0)) then { _buffer = 200; };
if (_buffer < 0) then { _buffer = 0; };

{
    private _pPos = getPosATL _x;
    {
        _last set [_x, _now];
    } forEach ([_pPos, _buffer] call ARC_fnc_civsubDistrictsWithinBuffer);
} forEach _players;

// Compute active districts as those seen within grace window.
// Pair each candidate with its age (now - lastSeen) so we can prioritise the
// districts players currently/most-recently occupy.
private _cand = [];
{
    private _did = _x;
    private _ts = [_last, _did, -1] call _hg;
    if (_ts >= 0 && {(_now - _ts) <= _grace}) then {
        _cand pushBack [(_now - _ts), _did];
    };
} forEach ([_last] call _keysFn);

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
