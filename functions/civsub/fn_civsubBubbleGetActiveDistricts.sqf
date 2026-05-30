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
      - Refresh last-seen for every district within radius_m + buffer of a player
        (buffer = civsub_v1_activeDistrict_buffer_m, default 200) to match the
        canonical ARC_fnc_civsubIsDistrictActive definition. Without this, a
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

// Update last-seen for districts within the activation buffer of any player.
// Matches the canonical activation definition in ARC_fnc_civsubIsDistrictActive
// (dist <= radius_m + buffer). Using the same buffer here (rather than strict
// centroid+radius containment via FindByPos) prevents civilians despawning when
// a stationary player sits just outside a — often small — district radius: their
// presence keeps refreshing last-seen so the grace window never expires.
private _buffer = missionNamespace getVariable ["civsub_v1_activeDistrict_buffer_m", 200];
if (!(_buffer isEqualType 0)) then { _buffer = 200; };
if (_buffer < 0) then { _buffer = 0; };

private _hgD = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _hmCreateD = compile "params ['_a']; createHashMapFromArray _a";
private _keysFnD = compile "params ['_m']; keys _m";

private _districts = missionNamespace getVariable ["civsub_v1_districts", createHashMap];
if !(_districts isEqualType createHashMap) then { _districts = createHashMap; };

{
    private _pPos = getPosATL _x;
    {
        private _did2 = _x;
        private _rec = [_districts, _did2, createHashMap] call _hgD;
        if (_rec isEqualType []) then { _rec = [_rec] call _hmCreateD; };
        if (_rec isEqualType createHashMap) then {
            private _c = [_rec, "centroid", [0,0]] call _hgD;
            private _r = [_rec, "radius_m", 0] call _hgD;
            if ((_c isEqualType []) && {(count _c) >= 2} && {_r > 0}) then {
                if ((_pPos distance2D [_c # 0, _c # 1, 0]) <= (_r + _buffer)) then {
                    _last set [_did2, _now];
                };
            };
        };
    } forEach ([_districts] call _keysFnD);
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
